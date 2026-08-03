class AddVocabularyToDealPipelines < ActiveRecord::Migration[7.1]
  def change
    add_column :deal_pipelines, :vocabulary, :jsonb, default: {}, null: false
  end
end
