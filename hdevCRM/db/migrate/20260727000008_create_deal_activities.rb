class CreateDealActivities < ActiveRecord::Migration[7.1]
  def change
    create_table :deal_activities do |t|
      t.bigint :deal_id, null: false
      t.bigint :account_id, null: false
      t.bigint :user_id
      t.integer :activity_type, null: false, default: 0
      t.bigint :from_stage_id
      t.bigint :to_stage_id
      t.jsonb :data, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :deal_activities, [:deal_id, :id]
    add_index :deal_activities, [:account_id, :created_at]
  end
end
