class CreatePlans < ActiveRecord::Migration[7.1]
  def change
    create_table :plans do |t|
      t.string :name, null: false
      t.integer :plan_type, default: 0, null: false
      t.integer :price_cents, default: 0, null: false
      t.string :currency, default: 'brl', null: false
      t.string :billing_interval, default: 'month', null: false
      t.string :stripe_price_id
      # Limites nulos significam ilimitado (grandfathering de quem não tem plano).
      t.integer :max_agents
      t.integer :max_inboxes
      t.integer :max_baileys_instances
      t.integer :max_client_accounts
      t.bigint :ai_monthly_tokens
      t.boolean :active, default: true, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :plans, [:plan_type, :active, :position]
    add_index :plans, :stripe_price_id, unique: true, where: 'stripe_price_id IS NOT NULL'
  end
end
