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
end
