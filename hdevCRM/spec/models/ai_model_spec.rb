require 'rails_helper'

RSpec.describe AiModel do
  describe 'validations' do
    it 'rejects a duplicate canonical_id' do
      create(:ai_model, canonical_id: 'modelo-x')
      expect(build(:ai_model, canonical_id: 'modelo-x')).not_to be_valid
    end
  end

  describe '.live' do
    it 'excludes deprecated models' do
      live = create(:ai_model)
      create(:ai_model, deprecated_at: 1.day.ago)
      expect(described_class.live.where(id: [live.id])).to contain_exactly(live)
    end
  end

  describe 'seed da migration' do
    it 'contains the 8 models from the old PRICES constant, haiku as default' do
      seeded = described_class.where(canonical_id: %w[claude-fable-5 claude-opus-5 claude-opus-4-8
                                                      claude-opus-4-7 claude-opus-4-6 claude-sonnet-5
                                                      claude-sonnet-4-6 claude-haiku-4-5])
      expect(seeded.count).to eq(8)
      expect(seeded.find_by(default_for_provider: true).canonical_id).to eq('claude-haiku-4-5')
    end
  end
end
