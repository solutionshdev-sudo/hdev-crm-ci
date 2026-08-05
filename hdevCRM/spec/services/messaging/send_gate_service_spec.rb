require 'rails_helper'

# Messaging::SendGateService é puro: recebe `now:` como argumento (não lê
# Time.current internamente, salvo dentro de Messaging::BaileysSendCounter,
# que é mockado aqui — o contador diário tem dono próprio, este spec só
# cobre a decisão do gate). Por isso os exemplos abaixo não precisam de
# `travel_to`: constroem os instantes diretamente e os injetam via `now:`
# e via `provider_config['paired_at']`.
describe Messaging::SendGateService do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:baileys_provider_config) { { 'instance_id' => 'instance-1', 'webhook_secret' => 'secret' } }

  # 12h local, dia comum, dentro da janela 7h-22h.
  let(:now) { Time.utc(2026, 8, 10, 12, 0, 0) }

  let(:baileys_channel) do
    create(:channel_whatsapp,
           provider: 'baileys',
           provider_config: baileys_provider_config,
           validate_provider_config: false,
           sync_templates: false,
           account: account)
  end

  # ban_risk: false (Messaging::Capabilities) — prova que o gate de janela/warm-up/cap
  # nunca arma fora do baileys, só o opt-out (que vale pra qualquer canal).
  let(:cloud_channel) do
    create(:channel_whatsapp, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false, account: account)
  end

  def decision_for(channel: baileys_channel, automated: true, at: now)
    described_class.new(channel: channel, contact: contact, automated: automated, now: at).call
  end

  def stub_daily_count(channel, count)
    counter = instance_double(Messaging::BaileysSendCounter, count: count)
    allow(Messaging::BaileysSendCounter).to receive(:new).with(channel: channel).and_return(counter)
  end

  def channel_paired(days_ago, extra_config = {})
    paired_at = (now - days_ago.days).iso8601
    create(:channel_whatsapp,
           provider: 'baileys',
           provider_config: baileys_provider_config.merge('paired_at' => paired_at).merge(extra_config),
           validate_provider_config: false,
           sync_templates: false,
           account: account)
  end

  before do
    stub_daily_count(baileys_channel, 0)
  end

  describe '#call' do
    context 'when the contact opted out of automation' do
      before { contact.update!(automation_opted_out: true) }

      it 'denies an automated message even on a channel without ban risk (opt-out applies everywhere)' do
        expect(decision_for(channel: cloud_channel, automated: true)).to eq({ deny: :opted_out })
      end

      it 'denies an automated message on a baileys channel too' do
        expect(decision_for(channel: baileys_channel, automated: true)).to eq({ deny: :opted_out })
      end

      it 'allows a human-authored message through' do
        expect(decision_for(channel: baileys_channel, automated: false)).to eq(:allow)
      end
    end

    context 'when the contact is blocked (global mute) instead of opted out' do
      before { contact.update!(blocked: true) }

      it 'denies the automated message the same way opt-out does' do
        expect(decision_for(channel: baileys_channel, automated: true)).to eq({ deny: :opted_out })
      end
    end

    context 'when the channel has no ban risk (whatsapp_cloud)' do
      it 'allows automated messages even outside the 7h-22h window' do
        outside_window = Time.utc(2026, 8, 10, 2, 0, 0)

        expect(decision_for(channel: cloud_channel, automated: true, at: outside_window)).to eq(:allow)
      end
    end

    context 'when the channel has ban risk and the message is automated' do
      it 'postpones just before 7am local' do
        at = Time.utc(2026, 8, 10, 6, 59, 0)

        expect(decision_for(at: at)).to eq({ postpone_until: Time.utc(2026, 8, 10, 7, 0, 0), reason: :outside_window })
      end

      it 'allows exactly at 7am local' do
        expect(decision_for(at: Time.utc(2026, 8, 10, 7, 0, 0))).to eq(:allow)
      end

      it 'allows at 21:59 local' do
        expect(decision_for(at: Time.utc(2026, 8, 10, 21, 59, 0))).to eq(:allow)
      end

      it 'postpones to the next day at exactly 22:00 local' do
        at = Time.utc(2026, 8, 10, 22, 0, 0)

        expect(decision_for(at: at)).to eq({ postpone_until: Time.utc(2026, 8, 11, 7, 0, 0), reason: :outside_window })
      end
    end

    context 'when the message is human-authored (not automated)' do
      it 'ignores the messaging window entirely' do
        outside_window = Time.utc(2026, 8, 10, 2, 0, 0)

        expect(decision_for(automated: false, at: outside_window)).to eq(:allow)
      end

      it 'still respects the daily cap, which protects the number regardless of who is sending' do
        stub_daily_count(baileys_channel, 300)

        expect(decision_for(automated: false)).to eq({ postpone_until: Time.utc(2026, 8, 11, 7, 0, 0), reason: :daily_cap })
      end
    end

    context 'when checking the warm-up schedule by pairing age' do
      it 'allows up to 20/day at day 0' do
        channel = channel_paired(0)
        stub_daily_count(channel, 19)

        expect(decision_for(channel: channel)).to eq(:allow)
      end

      it 'postpones past 20/day at day 0' do
        channel = channel_paired(0)
        stub_daily_count(channel, 20)

        expect(decision_for(channel: channel)).to eq({ postpone_until: Time.utc(2026, 8, 11, 7, 0, 0), reason: :warm_up_limit })
      end

      it 'still caps at 20/day one day before the 4-day turn' do
        channel = channel_paired(3)
        stub_daily_count(channel, 20)

        expect(decision_for(channel: channel)).to eq({ postpone_until: Time.utc(2026, 8, 11, 7, 0, 0), reason: :warm_up_limit })
      end

      it 'raises the cap to 50/day at day 4' do
        channel = channel_paired(4)
        stub_daily_count(channel, 49)

        expect(decision_for(channel: channel)).to eq(:allow)
      end

      it 'still caps at 50/day one day before the 8-day turn' do
        channel = channel_paired(7)
        stub_daily_count(channel, 50)

        expect(decision_for(channel: channel)).to eq({ postpone_until: Time.utc(2026, 8, 11, 7, 0, 0), reason: :warm_up_limit })
      end

      it 'raises the cap to 100/day at day 8' do
        channel = channel_paired(8)
        stub_daily_count(channel, 99)

        expect(decision_for(channel: channel)).to eq(:allow)
      end

      it 'still caps at 100/day one day before the 15-day turn' do
        channel = channel_paired(14)
        stub_daily_count(channel, 100)

        expect(decision_for(channel: channel)).to eq({ postpone_until: Time.utc(2026, 8, 11, 7, 0, 0), reason: :warm_up_limit })
      end

      it 'raises the cap to 200/day at day 15' do
        channel = channel_paired(15)
        stub_daily_count(channel, 199)

        expect(decision_for(channel: channel)).to eq(:allow)
      end

      it 'still caps at 200/day one day before the 31-day turn' do
        channel = channel_paired(30)
        stub_daily_count(channel, 200)

        expect(decision_for(channel: channel)).to eq({ postpone_until: Time.utc(2026, 8, 11, 7, 0, 0), reason: :warm_up_limit })
      end

      it 'removes the warm-up cap at day 31, leaving only the daily cap' do
        channel = channel_paired(31)
        stub_daily_count(channel, 1000)

        expect(decision_for(channel: channel)).to eq({ postpone_until: Time.utc(2026, 8, 11, 7, 0, 0), reason: :daily_cap })
      end
    end

    context 'when the channel never paired (no paired_at, no connected_jid)' do
      it 'treats the pairing age as zero (the strictest, 20/day step)' do
        channel = create(:channel_whatsapp,
                         provider: 'baileys',
                         provider_config: baileys_provider_config,
                         validate_provider_config: false,
                         sync_templates: false,
                         account: account)
        stub_daily_count(channel, 20)

        expect(decision_for(channel: channel)).to eq({ postpone_until: Time.utc(2026, 8, 11, 7, 0, 0), reason: :warm_up_limit })
      end
    end

    context 'when the channel paired before paired_at existed (legacy connected_jid only)' do
      it "falls back to the channel's created_at as the pairing epoch" do
        provider_config = baileys_provider_config.merge('connected_jid' => '5511999999999@s.whatsapp.net')
        channel = create(:channel_whatsapp,
                         provider: 'baileys',
                         provider_config: provider_config,
                         validate_provider_config: false,
                         sync_templates: false,
                         account: account,
                         created_at: now - 10.days)
        stub_daily_count(channel, 49)

        expect(decision_for(channel: channel, at: now)).to eq(:allow)
      end
    end

    context 'when the daily cap is configured on provider_config' do
      it 'uses the configured cap instead of the default 300' do
        channel = channel_paired(60, 'daily_send_cap' => 5)
        stub_daily_count(channel, 5)

        expect(decision_for(channel: channel, automated: false)).to eq({ postpone_until: Time.utc(2026, 8, 11, 7, 0, 0), reason: :daily_cap })
      end

      it 'treats a configured cap of zero as a kill switch for every sender' do
        channel = channel_paired(60, 'daily_send_cap' => 0)
        stub_daily_count(channel, 0)

        expect(decision_for(channel: channel, automated: false)).to eq({ postpone_until: Time.utc(2026, 8, 11, 7, 0, 0), reason: :daily_cap })
      end
    end

    context 'when the account has no reporting_timezone configured' do
      it 'falls back to UTC for the window check' do
        expect(decision_for(at: Time.utc(2026, 8, 10, 6, 59, 0))[:reason]).to eq(:outside_window)
      end
    end

    context 'when the account has a reporting_timezone configured' do
      let(:account) { create(:account, reporting_timezone: 'America/Sao_Paulo') }

      it 'uses the account timezone, not UTC, to decide the window' do
        # 9:00 UTC = 6:00 America/Sao_Paulo (UTC-3) -> fora da janela local, mesmo
        # que 9:00 estivesse dentro da janela em UTC puro.
        expect(decision_for(at: Time.utc(2026, 8, 10, 9, 0, 0))[:reason]).to eq(:outside_window)
      end

      it 'allows once the local hour (not the UTC hour) is inside the window' do
        # 10:00 UTC = 7:00 America/Sao_Paulo -> dentro da janela local.
        expect(decision_for(at: Time.utc(2026, 8, 10, 10, 0, 0))).to eq(:allow)
      end
    end

    context 'when the order between gates matters' do
      it 'opt-out wins over the messaging window' do
        contact.update!(automation_opted_out: true)
        outside_window = Time.utc(2026, 8, 10, 2, 0, 0)

        expect(decision_for(at: outside_window)).to eq({ deny: :opted_out })
      end

      it 'the messaging window wins over warm-up' do
        channel = channel_paired(0)
        # 25 já estouraria o warm-up (limite 20 aos 0 dias) se ele fosse checado
        # primeiro — a janela vence antes de chegar lá.
        stub_daily_count(channel, 25)
        outside_window = Time.utc(2026, 8, 10, 2, 0, 0)

        expect(decision_for(channel: channel, at: outside_window)[:reason]).to eq(:outside_window)
      end

      it 'warm-up wins over the daily cap' do
        # daily_send_cap 15 é MENOR que o limite de warm-up (20) — se o cap diário
        # fosse checado primeiro, a razão seria :daily_cap.
        channel = channel_paired(0, 'daily_send_cap' => 15)
        stub_daily_count(channel, 20)

        expect(decision_for(channel: channel)[:reason]).to eq(:warm_up_limit)
      end
    end
  end
end
