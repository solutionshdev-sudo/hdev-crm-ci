require 'rails_helper'

RSpec.describe DealPipeline do
  let(:account) { create(:account) }

  describe 'vocabulary validation' do
    it 'is valid with an empty vocabulary' do
      pipeline = build(:deal_pipeline, account: account)

      expect(pipeline).to be_valid
    end

    it 'is invalid when a known key is set to an empty string' do
      pipeline = build(:deal_pipeline, account: account, vocabulary: { 'lead' => '' })

      expect(pipeline).to be_invalid
      expect(pipeline.errors[:vocabulary]).to include(I18n.t('errors.models.deal_pipeline.vocabulary_length', key: 'lead'))
    end

    it 'is invalid when a known key is longer than 40 characters' do
      pipeline = build(:deal_pipeline, account: account, vocabulary: { 'deal' => 'a' * 41 })

      expect(pipeline).to be_invalid
      expect(pipeline.errors[:vocabulary]).to include(I18n.t('errors.models.deal_pipeline.vocabulary_length', key: 'deal'))
    end

    it 'is valid at exactly 40 characters' do
      pipeline = build(:deal_pipeline, account: account, vocabulary: { 'deal' => 'a' * 40 })

      expect(pipeline).to be_valid
    end

    it 'is valid at exactly 1 character' do
      pipeline = build(:deal_pipeline, account: account, vocabulary: { 'won' => 'G' })

      expect(pipeline).to be_valid
    end

    it 'ignores unknown keys in the jsonb' do
      pipeline = build(:deal_pipeline, account: account, vocabulary: { 'unknown' => '' })

      expect(pipeline).to be_valid
    end

    it 'persists only the keys given, without injecting a default for the others' do
      pipeline = create(:deal_pipeline, account: account, vocabulary: { 'lost' => 'Cancelado' })

      expect(pipeline.reload.vocabulary).to eq('lost' => 'Cancelado')
    end
  end
end
