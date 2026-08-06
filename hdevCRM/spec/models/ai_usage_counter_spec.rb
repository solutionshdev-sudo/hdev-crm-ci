require 'rails_helper'

RSpec.describe AiUsageCounter do
  let(:account) { create(:account) }
  let(:period) { Time.zone.today.beginning_of_month }

  describe '.record!' do
    it 'creates the counter row on first use' do
      described_class.record!(owner: account, period_start: period, tokens: 100, cost: 0.001)

      counter = described_class.find_by(owner: account, period_start: period)
      expect(counter.tokens).to eq(100)
      expect(counter.cost).to eq(0.001)
    end

    it 'accumulates instead of overwriting on subsequent events' do
      described_class.record!(owner: account, period_start: period, tokens: 100, cost: 0.001)
      described_class.record!(owner: account, period_start: period, tokens: 50, cost: 0.0005)

      counter = described_class.find_by(owner: account, period_start: period)
      expect(counter.tokens).to eq(150)
      expect(counter.cost).to eq(0.0015)
    end

    it 'keeps separate rows per owner and per month' do
      agency = create(:agency)
      described_class.record!(owner: account, period_start: period, tokens: 10, cost: 0.1)
      described_class.record!(owner: agency, period_start: period, tokens: 20, cost: 0.2)
      described_class.record!(owner: account, period_start: period - 1.month, tokens: 30, cost: 0.3)

      expect(described_class.count).to eq(3)
      expect(described_class.find_by(owner: account, period_start: period).tokens).to eq(10)
    end

    it 'survives the creation race by retrying after RecordNotUnique' do
      calls = 0
      allow(described_class).to receive(:find_or_create_by!).and_wrap_original do |original, *args, &block|
        calls += 1
        raise ActiveRecord::RecordNotUnique, 'duplicate key' if calls == 1

        original.call(*args, &block)
      end

      expect do
        described_class.record!(owner: account, period_start: period, tokens: 5, cost: 0.05)
      end.not_to raise_error

      expect(described_class.find_by(owner: account, period_start: period).tokens).to eq(5)
    end
  end

  describe '.current_for' do
    it 'returns the counter of the current month' do
      described_class.record!(owner: account, period_start: period, tokens: 42, cost: 0.42)
      described_class.record!(owner: account, period_start: period - 1.month, tokens: 999, cost: 9.99)

      expect(described_class.current_for(account).tokens).to eq(42)
    end

    it 'is nil when the owner has no usage this month' do
      expect(described_class.current_for(account)).to be_nil
    end
  end
end
