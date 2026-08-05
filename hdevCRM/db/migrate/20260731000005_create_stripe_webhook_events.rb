class CreateStripeWebhookEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :stripe_webhook_events do |t|
      t.string :stripe_event_id, null: false
      t.string :event_type, null: false
      t.jsonb :payload, default: {}, null: false
      t.integer :status, default: 0, null: false
      t.datetime :processed_at
      t.text :error

      t.timestamps
    end

    add_index :stripe_webhook_events, :stripe_event_id, unique: true
    add_index :stripe_webhook_events, [:status, :created_at]
  end
end
