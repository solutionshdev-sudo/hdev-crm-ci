class CreateSubscriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :subscriptions do |t|
      t.string :owner_type, null: false
      t.bigint :owner_id, null: false
      t.references :plan, null: false, foreign_key: true
      t.string :stripe_customer_id
      t.string :stripe_subscription_id
      t.integer :status, default: 0, null: false
      t.datetime :current_period_end

      t.timestamps
    end

    # Uma assinatura por dono (Agency ou Account).
    add_index :subscriptions, [:owner_type, :owner_id], unique: true
    add_index :subscriptions, :stripe_customer_id
    add_index :subscriptions, :stripe_subscription_id, unique: true, where: 'stripe_subscription_id IS NOT NULL'
  end
end
