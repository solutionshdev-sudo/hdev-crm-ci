require 'rails_helper'

RSpec.describe Ai::Pricing do
  describe '.for_model' do
    it 'returns the price entry for known models' do
      expect(described_class.for_model('claude-opus-4-8')).to eq(input: 5.0, output: 25.0)
      expect(described_class.for_model('claude-haiku-4-5')).to eq(input: 1.0, output: 5.0)
    end

    it 'falls back to the default for unknown models' do
      expect(described_class.for_model('some-future-model')).to eq(described_class::DEFAULT)
    end
  end

  describe '.cost' do
    it 'computes cost in USD from tokens' do
      # 1M input at $5 + 1M output at $25
      expect(described_class.cost('claude-opus-4-8', 1_000_000, 1_000_000)).to eq(30.0)
    end

    it 'computes fractional costs' do
      expect(described_class.cost('claude-haiku-4-5', 1000, 500)).to be_within(1e-9).of(0.0035)
    end

    it 'handles nil tokens as zero' do
      expect(described_class.cost('claude-opus-4-8', nil, nil)).to eq(0.0)
    end
  end

  describe 'DB-backed prices (F8)' do
    after { described_class.reset_cache! }

    it 'reads the current price row for a catalog model' do
      model = create(:ai_model)
      create(:ai_model_price, ai_model: model, input_cents_per_million: 700, output_cents_per_million: 1400)
      described_class.reset_cache!

      expect(described_class.for_model(model.canonical_id)).to eq(input: 7.0, output: 14.0)
      expect(described_class.cost(model.canonical_id, 1_000_000, 1_000_000)).to eq(21.0)
    end

    it 'ignores superseded rows' do
      model = create(:ai_model)
      create(:ai_model_price, ai_model: model, input_cents_per_million: 100, output_cents_per_million: 100,
                              superseded_at: 1.hour.ago)
      create(:ai_model_price, ai_model: model, input_cents_per_million: 900, output_cents_per_million: 900)
      described_class.reset_cache!

      expect(described_class.for_model(model.canonical_id)).to eq(input: 9.0, output: 9.0)
    end

    it 'caches lookups for five minutes' do
      model = create(:ai_model)
      create(:ai_model_price, ai_model: model, input_cents_per_million: 100, output_cents_per_million: 500)
      described_class.reset_cache!
      described_class.for_model(model.canonical_id)

      expect(AiModelPrice).not_to receive(:joins)
      described_class.for_model(model.canonical_id)
    end
  end
end
