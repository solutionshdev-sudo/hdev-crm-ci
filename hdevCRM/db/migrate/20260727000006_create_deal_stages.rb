class CreateDealStages < ActiveRecord::Migration[7.1]
  def change
    create_table :deal_stages do |t|
      t.bigint :account_id, null: false
      t.bigint :deal_pipeline_id, null: false
      t.string :name, null: false
      t.string :color, null: false, default: '#64748B'
      t.integer :position, null: false, default: 0
      t.integer :probability, null: false, default: 0
      t.integer :stage_type, null: false, default: 0
      t.timestamps
    end
    add_index :deal_stages, [:deal_pipeline_id, :position]
    add_index :deal_stages, :account_id
  end
end
