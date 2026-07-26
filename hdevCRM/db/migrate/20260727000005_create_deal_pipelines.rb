class CreateDealPipelines < ActiveRecord::Migration[7.1]
  def change
    create_table :deal_pipelines do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.string :description
      t.integer :position, null: false, default: 0
      t.boolean :is_default, null: false, default: false
      t.datetime :archived_at
      t.timestamps
    end
    add_index :deal_pipelines, [:account_id, :position]
  end
end
