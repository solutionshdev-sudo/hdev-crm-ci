require 'rails_helper'

RSpec.describe DealPipeline do
  let(:account) { create(:account) }

  describe '#vocabulary_label' do
    it 'returns the product default for each concept when vocabulary is empty' do
      pipeline = create(:deal_pipeline, account: account)

      expect(pipeline.vocabulary_label(:lead)).to eq('Lead')
      expect(pipeline.vocabulary_label(:deal)).to eq('Negócio')
      expect(pipeline.vocabulary_label(:won)).to eq('Ganho')
      expect(pipeline.vocabulary_label(:lost)).to eq('Perdido')
    end

    it 'returns the custom label when the key is overridden, keeping the others at default' do
      pipeline = create(:deal_pipeline, account: account, vocabulary: { 'lost' => 'Cancelado' })

      expect(pipeline.vocabulary_label(:lost)).to eq('Cancelado')
      expect(pipeline.vocabulary_label(:deal)).to eq('Negócio')
    end

    it 'accepts a string key just like a symbol' do
      pipeline = create(:deal_pipeline, account: account, vocabulary: { 'deal' => 'Oportunidade' })

      expect(pipeline.vocabulary_label('deal')).to eq('Oportunidade')
    end
  end

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
  end
end
