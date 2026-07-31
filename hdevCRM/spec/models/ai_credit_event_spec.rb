require 'rails_helper'

RSpec.describe AiCreditEvent do
  describe 'validations' do
    it 'rejects a zero delta' do
      expect(build(:ai_credit_event, delta: 0)).not_to be_valid
    end
  end

  describe '.record!' do
    it 'creates the ledger entry and increments the account balance atomically' do
      account = create(:account)

      event = described_class.record!(owner: account, delta: 500_000, reason: :topup, description: 'Pacote 500k')

      expect(event).to be_persisted
      expect(event.reason).to eq('topup')
      expect(account.reload.ai_extra_tokens).to eq(500_000)
    end

    it 'decrements the balance for consumption entries on agencies' do
      agency = create(:agency)
      described_class.record!(owner: agency, delta: 100_000, reason: :manual_grant)

      described_class.record!(owner: agency, delta: -40_000, reason: :consumption)

      expect(agency.reload.ai_extra_tokens).to eq(60_000)
    end

    it 'does not change the balance when the ledger entry is rejected' do
      account = create(:account)
      described_class.record!(owner: account, delta: 1000, reason: :topup, stripe_event_id: 'evt_dup')

      expect do
        described_class.record!(owner: account, delta: 1000, reason: :topup, stripe_event_id: 'evt_dup')
      end.to raise_error(ActiveRecord::RecordInvalid)

      expect(account.reload.ai_extra_tokens).to eq(1000)
    end
  end
end
