require 'rails_helper'

# Mesmo padrão de spec/models/concerns/account_email_rate_limitable_spec.rb
# (a fonte que o próprio BaileysSendCounter cita): INCR real pro round-trip,
# stub de Redis::Alfred só pros dois testes de TTL.
describe Messaging::BaileysSendCounter do
  after do
    Redis::Alfred.scan_each(match: 'baileys:sent:*') { |key| Redis::Alfred.delete(key) }
  end

  let(:account) { create(:account) }
  let(:channel) do
    create(:channel_whatsapp,
           provider: 'baileys',
           provider_config: { 'instance_id' => 'instance-1', 'webhook_secret' => 'secret' },
           validate_provider_config: false,
           sync_templates: false,
           account: account)
  end
  let(:counter) { described_class.new(channel: channel) }

  describe '#increment! and #count' do
    it 'round-trips through Redis' do
      expect { counter.increment! }.to change { counter.count }.from(0).to(1)
    end

    context 'with the first increment of the day' do
      it 'sets the TTL' do
        allow(Redis::Alfred).to receive(:incr).and_return(1)
        allow(Redis::Alfred).to receive(:expire)

        counter.increment!

        expect(Redis::Alfred).to have_received(:expire).with(anything, described_class::EXPIRY)
      end
    end

    context 'with a subsequent increment on the same day' do
      it 'does not reset the TTL' do
        allow(Redis::Alfred).to receive(:incr).and_return(2)
        allow(Redis::Alfred).to receive(:expire)

        counter.increment!

        expect(Redis::Alfred).not_to have_received(:expire)
      end
    end
  end

  it 'keys Redis as baileys:sent:<instance_id>:<yyyymmdd>' do
    counter.increment!(now: Time.utc(2026, 8, 10, 12, 0, 0))

    expect(Redis::Alfred.get('baileys:sent:instance-1:20260810').to_i).to eq(1)
  end

  context 'when two accounts in different timezones send at the same UTC instant' do
    it 'lands on different day keys instead of sharing one counter' do
      provider_config = { 'instance_id' => 'instance-shared', 'webhook_secret' => 'secret' }
      utc_channel = create(:channel_whatsapp,
                           provider: 'baileys',
                           provider_config: provider_config,
                           validate_provider_config: false,
                           sync_templates: false,
                           account: create(:account))
      sp_channel = create(:channel_whatsapp,
                          provider: 'baileys',
                          provider_config: provider_config,
                          validate_provider_config: false,
                          sync_templates: false,
                          account: create(:account, reporting_timezone: 'America/Sao_Paulo'))
      # 01:00 UTC = 22:00 em Sao Paulo (UTC-3) do dia anterior -> datas locais diferentes.
      now = Time.utc(2026, 8, 11, 1, 0, 0)

      described_class.new(channel: utc_channel).increment!(now: now)

      expect(described_class.new(channel: sp_channel).count(now: now)).to eq(0)
      expect(described_class.new(channel: utc_channel).count(now: now)).to eq(1)
    end
  end
end
