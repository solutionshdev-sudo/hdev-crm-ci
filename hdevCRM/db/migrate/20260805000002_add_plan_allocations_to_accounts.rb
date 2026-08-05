class AddPlanAllocationsToAccounts < ActiveRecord::Migration[7.1]
  def change
    # A fatia do pool que a agência distribuiu pra esta conta. Mesmas chaves de
    # Plan::LIMIT_ATTRIBUTES + "channel_limits"; chave presente vence o plano
    # na cadeia do Plan::LimitEnforcer (null = ilimitado explícito).
    add_column :accounts, :plan_allocations, :jsonb, default: {}, null: false
  end
end
