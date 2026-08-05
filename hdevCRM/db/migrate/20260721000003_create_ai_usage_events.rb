class CreateAiUsageEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :ai_usage_events do |t|
      t.references :account, null: false, index: true
      t.references :agency, index: true
      t.references :conversation, index: false
      t.string :feature
      t.string :model, null: false
      t.integer :input_tokens, default: 0, null: false
      t.integer :output_tokens, default: 0, null: false
      t.integer :total_tokens, default: 0, null: false
      t.decimal :cost, precision: 12, scale: 8, default: 0, null: false
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :ai_usage_events, [:account_id, :created_at]
    add_index :ai_usage_events, [:agency_id, :created_at]
  end
end
