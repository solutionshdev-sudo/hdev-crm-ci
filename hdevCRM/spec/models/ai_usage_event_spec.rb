require 'rails_helper'

RSpec.describe AiUsageEvent do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:model) }
  end

  describe '.record!' do
    let(:agency) { create(:agency) }
    let(:account) { create(:account, agency: agency) }

    it 'computes totals, cost and denormalizes the agency' do
      event = described_class.record!(
        account: account,
        model: 'claude-opus-4-8',
        input_tokens: 1000,
        output_tokens: 500,
        feature: 'chatbot'
      )

      expect(event.total_tokens).to eq(1500)
      expect(event.agency_id).to eq(agency.id)
      # 1000 * $5/1M + 500 * $25/1M
      expect(event.cost.to_f).to be_within(1e-9).of(0.0175)
    end

    it 'records events for accounts without an agency' do
      event = described_class.record!(
        account: create(:account),
        model: 'claude-haiku-4-5',
        input_tokens: 10,
        output_tokens: 10
      )
      expect(event.agency_id).to be_nil
    end
  end

  describe '.summary' do
    let(:account) { create(:account) }

    it 'aggregates tokens and cost' do
      create(:ai_usage_event, account: account, input_tokens: 1000, output_tokens: 500)
      create(:ai_usage_event, account: account, input_tokens: 2000, output_tokens: 1000)

      summary = described_class.where(account_id: account.id).summary
      expect(summary[:input_tokens]).to eq(3000)
      expect(summary[:output_tokens]).to eq(1500)
      expect(summary[:total_tokens]).to eq(4500)
      expect(summary[:cost]).to be > 0
    end
  end

  describe 'usage counters (F7.5)' do
    let(:agency) { create(:agency) }
    let(:account) { create(:account, agency: agency) }

    it 'increments the account and agency counters in the month of the event' do
      create(:ai_usage_event, account: account, input_tokens: 1000, output_tokens: 500)
      create(:ai_usage_event, account: account, input_tokens: 200, output_tokens: 100)

      period = Time.zone.today.beginning_of_month
      expect(AiUsageCounter.find_by(owner: account, period_start: period).tokens).to eq(1800)
      expect(AiUsageCounter.find_by(owner: agency, period_start: period).tokens).to eq(1800)
    end

    it 'matches the SUM over events, tokens and cost alike' do
      [[1000, 500], [123, 45], [10, 1]].each do |input, output|
        create(:ai_usage_event, account: account, input_tokens: input, output_tokens: output)
      end

      counter = AiUsageCounter.current_for(account)
      events = described_class.where(account_id: account.id)
      expect(counter.tokens).to eq(events.sum(:total_tokens))
      expect(counter.cost).to eq(events.sum(:cost))
    end

    it 'does not touch the agency counter for accounts without an agency' do
      create(:ai_usage_event, account: create(:account), input_tokens: 10, output_tokens: 10)

      expect(AiUsageCounter.where(owner_type: 'Agency')).to be_empty
    end

    it 'keys the counter to the month the event was created in' do
      travel_to(2.months.ago) do
        create(:ai_usage_event, account: account, input_tokens: 100, output_tokens: 0)
      end

      expect(AiUsageCounter.current_for(account)).to be_nil
      expect(AiUsageCounter.find_by(owner: account).tokens).to eq(100)
    end

    it 'enqueues the quota alert job instead of mailing synchronously' do
      enqueues_job = have_enqueued_job(Ai::QuotaAlertJob).with(account.id)
      no_sync_mail = not_have_enqueued_mail(AdministratorNotifications::AccountNotificationMailer, :ai_quota_threshold)

      expect do
        create(:ai_usage_event, account: account, input_tokens: 10, output_tokens: 10)
      end.to enqueues_job.and(no_sync_mail)
    end
  end
end
