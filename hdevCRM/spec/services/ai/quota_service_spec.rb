require 'rails_helper'

RSpec.describe Ai::QuotaService do
  let(:agency) { create(:agency) }
  let(:account) { create(:account, agency: agency) }
  let(:service) { described_class.new(account: account) }

  describe '#exceeded?' do
    it 'is false when no limits are configured' do
      create(:ai_usage_event, account: account, input_tokens: 1_000_000, output_tokens: 0)
      expect(service.exceeded?).to be(false)
    end

    it 'is true when the account monthly limit is reached' do
      account.update!(custom_attributes: { 'ai_monthly_tokens' => 1000 })
      create(:ai_usage_event, account: account, input_tokens: 900, output_tokens: 200)
      expect(service.exceeded?).to be(true)
    end

    it 'is false while under the account limit' do
      account.update!(custom_attributes: { 'ai_monthly_tokens' => 10_000 })
      create(:ai_usage_event, account: account, input_tokens: 900, output_tokens: 200)
      expect(service.exceeded?).to be(false)
    end

    it 'is true when the agency limit is reached across its accounts' do
      agency.update!(settings: { 'ai_monthly_tokens' => 2000 })
      other_account = create(:account, agency: agency)
      create(:ai_usage_event, account: account, input_tokens: 800, output_tokens: 200)
      create(:ai_usage_event, account: other_account, input_tokens: 800, output_tokens: 300)
      expect(service.exceeded?).to be(true)
    end

    it 'ignores usage from previous months' do
      account.update!(custom_attributes: { 'ai_monthly_tokens' => 1000 })
      event = create(:ai_usage_event, account: account, input_tokens: 2000, output_tokens: 0)
      event.update_columns(created_at: 2.months.ago) # rubocop:disable Rails/SkipsModelValidations
      expect(service.exceeded?).to be(false)
    end
  end

  describe '#account_summary' do
    it 'returns usage, limit and exceeded flag' do
      account.update!(custom_attributes: { 'ai_monthly_tokens' => 5000 })
      create(:ai_usage_event, account: account, input_tokens: 1000, output_tokens: 500)

      summary = service.account_summary
      expect(summary[:monthly_limit]).to eq(5000)
      expect(summary[:tokens_used]).to eq(1500)
      expect(summary[:exceeded]).to be(false)
      expect(summary[:usage][:total_tokens]).to eq(1500)
    end
  end

  describe '#account_limit' do
    it 'uses the plan limit when the subscription is active' do
      plan = create(:plan, ai_monthly_tokens: 1000)
      create(:subscription, owner: account, plan: plan, status: 'active')
      account.update!(custom_attributes: { 'ai_monthly_tokens' => 50 }) # deve ser ignorado: plano manda

      expect(service.account_limit).to eq(1000)
    end

    it 'uses the plan limit when the subscription is past_due' do
      plan = create(:plan, ai_monthly_tokens: 2000)
      create(:subscription, owner: account, plan: plan, status: 'past_due')

      expect(service.account_limit).to eq(2000)
    end

    it 'falls back to custom_attributes when the subscription is canceled' do
      plan = create(:plan, ai_monthly_tokens: 2000)
      create(:subscription, owner: account, plan: plan, status: 'canceled')
      account.update!(custom_attributes: { 'ai_monthly_tokens' => 300 })

      expect(service.account_limit).to eq(300)
    end

    it 'falls back to custom_attributes when there is no subscription' do
      account.update!(custom_attributes: { 'ai_monthly_tokens' => 400 })

      expect(service.account_limit).to eq(400)
    end

    it 'is unlimited when the plan has no cap, even with extra tokens' do
      plan = create(:plan, ai_monthly_tokens: nil)
      create(:subscription, owner: account, plan: plan, status: 'active')
      account.update!(ai_extra_tokens: 500)

      expect(service.account_limit).to be_nil
    end

    # Decisão do controller (promovida a spec): com subscription ativa, o
    # plano manda sempre -- mesmo quando ai_monthly_tokens é nil (ilimitado)
    # e existe um custom_attributes legado populado. O fallback NÃO
    # ressuscita: uma conta pagante de plano ilimitado não pode ficar
    # estrangulada por um valor velho do custom_attributes.
    it 'does not resurrect the legacy fallback when the active plan is explicitly unlimited' do
      plan = create(:plan, ai_monthly_tokens: nil)
      create(:subscription, owner: account, plan: plan, status: 'active')
      account.update!(custom_attributes: { 'ai_monthly_tokens' => 5000 })

      expect(service.account_limit).to be_nil
    end

    it 'sums ai_extra_tokens on top of the plan limit' do
      plan = create(:plan, ai_monthly_tokens: 1000)
      create(:subscription, owner: account, plan: plan, status: 'active')
      account.update!(ai_extra_tokens: 250)

      expect(service.account_limit).to eq(1250)
    end

    it 'sums ai_extra_tokens on top of the fallback limit' do
      account.update!(custom_attributes: { 'ai_monthly_tokens' => 500 }, ai_extra_tokens: 100)

      expect(service.account_limit).to eq(600)
    end

    # F6: a fatia que a agência alocou (plan_allocations) vence a cadeia
    # inteira quando a chave existe.
    context 'with a plan allocation from the agency (F6)' do
      it 'wins over the plan of an active subscription' do
        plan = create(:plan, ai_monthly_tokens: 9000)
        create(:subscription, owner: account, plan: plan, status: 'active')
        account.update!(plan_allocations: { 'ai_monthly_tokens' => 1000 })

        expect(service.account_limit).to eq(1000)
      end

      it 'treats an explicit null allocation as unlimited, even with extra tokens' do
        plan = create(:plan, ai_monthly_tokens: 9000)
        create(:subscription, owner: account, plan: plan, status: 'active')
        account.update!(plan_allocations: { 'ai_monthly_tokens' => nil }, ai_extra_tokens: 500)

        expect(service.account_limit).to be_nil
      end

      it 'sums ai_extra_tokens on top of a finite allocation' do
        account.update!(plan_allocations: { 'ai_monthly_tokens' => 1000 }, ai_extra_tokens: 200)

        expect(service.account_limit).to eq(1200)
      end

      it 'keeps the regular chain when the allocation lacks the key' do
        account.update!(plan_allocations: { 'max_agents' => 2 }, custom_attributes: { 'ai_monthly_tokens' => 400 })

        expect(service.account_limit).to eq(400)
      end
    end
  end

  describe '#agency_limit' do
    it 'uses the plan limit plus extra tokens when the agency subscription is active' do
      plan = create(:plan, ai_monthly_tokens: 3000)
      create(:subscription, owner: agency, plan: plan, status: 'active')
      agency.update!(ai_extra_tokens: 500)

      expect(service.agency_limit).to eq(3500)
    end

    it 'falls back to settings when the agency has no subscription' do
      agency.update!(settings: { 'ai_monthly_tokens' => 700 })

      expect(service.agency_limit).to eq(700)
    end
  end

  describe '#check_thresholds!' do
    around do |example|
      travel_to(Time.zone.local(2026, 6, 15, 12, 0, 0)) { example.run }
    end

    before { account.update!(custom_attributes: { 'ai_monthly_tokens' => 1000 }) }

    after do
      Redis::Alfred.delete(format(Redis::RedisKeys::AI_QUOTA_ALERT_KEY, account_id: account.id, threshold: 80))
      Redis::Alfred.delete(format(Redis::RedisKeys::AI_QUOTA_ALERT_KEY, account_id: account.id, threshold: 100))
    end

    it 'does not enqueue a mail below the 80% threshold' do
      create(:ai_usage_event, account: account, input_tokens: 790, output_tokens: 0)

      expect { service.check_thresholds! }
        .not_to have_enqueued_mail(AdministratorNotifications::AccountNotificationMailer, :ai_quota_threshold)
    end

    it 'enqueues the 80% alert once usage crosses the threshold' do
      create(:ai_usage_event, account: account, input_tokens: 800, output_tokens: 0)

      expect { service.check_thresholds! }
        .to have_enqueued_mail(AdministratorNotifications::AccountNotificationMailer, :ai_quota_threshold)
    end

    it 'does not enqueue a second 80% alert within the cooldown window' do
      create(:ai_usage_event, account: account, input_tokens: 800, output_tokens: 0)
      service.check_thresholds!

      expect { service.check_thresholds! }
        .not_to have_enqueued_mail(AdministratorNotifications::AccountNotificationMailer, :ai_quota_threshold)
    end

    it 'sends a new 80% alert once the cooldown key is cleared' do
      create(:ai_usage_event, account: account, input_tokens: 800, output_tokens: 0)
      service.check_thresholds!
      Redis::Alfred.delete(format(Redis::RedisKeys::AI_QUOTA_ALERT_KEY, account_id: account.id, threshold: 80))

      expect { service.check_thresholds! }
        .to have_enqueued_mail(AdministratorNotifications::AccountNotificationMailer, :ai_quota_threshold)
    end

    it 'enqueues only the exhausted alert at 100%, never also the 80% alert' do
      create(:ai_usage_event, account: account, input_tokens: 1000, output_tokens: 0)

      expect { service.check_thresholds! }
        .to have_enqueued_mail(AdministratorNotifications::AccountNotificationMailer, :ai_quota_exhausted)
        .and(not_have_enqueued_mail(AdministratorNotifications::AccountNotificationMailer, :ai_quota_threshold))
    end

    it 'does nothing when the account has no configured limit' do
      account.update!(custom_attributes: {})
      create(:ai_usage_event, account: account, input_tokens: 999_999, output_tokens: 0)

      expect { service.check_thresholds! }
        .not_to have_enqueued_mail(AdministratorNotifications::AccountNotificationMailer, :ai_quota_threshold)
      expect { service.check_thresholds! }
        .not_to have_enqueued_mail(AdministratorNotifications::AccountNotificationMailer, :ai_quota_exhausted)
    end

    it 'never raises when Redis is unavailable' do
      create(:ai_usage_event, account: account, input_tokens: 800, output_tokens: 0)
      allow(Redis::Alfred).to receive(:set).and_raise(StandardError, 'boom')

      expect { service.check_thresholds! }.not_to raise_error
    end
  end
end
