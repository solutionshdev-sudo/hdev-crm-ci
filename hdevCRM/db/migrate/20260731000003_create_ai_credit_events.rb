class CreateAiCreditEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :ai_credit_events do |t|
      t.string :owner_type, null: false
      t.bigint :owner_id, null: false
      t.bigint :delta, null: false
      t.integer :reason, default: 0, null: false
      t.string :stripe_event_id
      t.string :description
      t.bigint :created_by_id

      t.timestamps
    end

    add_index :ai_credit_events, [:owner_type, :owner_id]
    add_index :ai_credit_events, :stripe_event_id, unique: true, where: 'stripe_event_id IS NOT NULL'
  end
end
