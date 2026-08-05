class CreateDeals < ActiveRecord::Migration[7.1]
  def change
    create_table :deals do |t|
      t.bigint :account_id, null: false
      t.bigint :deal_pipeline_id, null: false
      t.bigint :deal_stage_id, null: false
      t.bigint :contact_id, null: false
      t.bigint :conversation_id
      t.bigint :assignee_id
      t.bigint :created_by_id
      t.string :title, null: false
      t.text :description
      t.decimal :value, precision: 15, scale: 2, null: false, default: 0
      t.string :currency, null: false, default: 'BRL'
      t.integer :status, null: false, default: 0
      # Decimal position: drag-and-drop inserts at the midpoint of the two
      # neighbours (single-row UPDATE) instead of rewriting the column.
      t.decimal :position, precision: 20, scale: 10, null: false, default: 0
      t.date :expected_close_on
      t.datetime :closed_at
      t.string :lost_reason
      t.jsonb :custom_attributes, null: false, default: {}
      t.timestamps
    end
    add_index :deals, [:account_id, :status]
    add_index :deals, [:deal_stage_id, :position]
    add_index :deals, :contact_id
    add_index :deals, :conversation_id
    add_index :deals, :assignee_id
  end
end
