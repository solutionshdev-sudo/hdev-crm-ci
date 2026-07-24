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
end
