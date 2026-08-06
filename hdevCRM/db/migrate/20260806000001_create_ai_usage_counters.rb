class CreateAiUsageCounters < ActiveRecord::Migration[7.1]
  # F7.5: tira o SUM(total_tokens) do hot path da quota. Um registro por
  # dono (Account|Agency) por mês; incrementado atomicamente pelo
  # after_create de AiUsageEvent. Custo em decimal(14,8) — mesma escala do
  # evento; centavo arredondado por evento zeraria conta pequena.
  def up
    create_table :ai_usage_counters do |t|
      t.string :owner_type, null: false
      t.bigint :owner_id, null: false
      t.date :period_start, null: false
      t.bigint :tokens, null: false, default: 0
      t.decimal :cost, precision: 14, scale: 8, null: false, default: 0
      t.timestamps
    end
    add_index :ai_usage_counters, [:owner_type, :owner_id, :period_start],
              unique: true, name: 'index_ai_usage_counters_on_owner_and_period'

    backfill_account_counters
    backfill_agency_counters
  end

  def down
    drop_table :ai_usage_counters
  end

  private

  # Backfill: sem ele, deploy no meio do mês zera o consumo aparente e
  # conta que já estourou a quota volta a gastar. Agrupa por mês em UTC
  # (date_trunc); o runtime usa Time.zone — desvio de borda aceito para
  # dado histórico (design doc, seção 1).
  def backfill_account_counters
    execute <<~SQL.squish
      INSERT INTO ai_usage_counters (owner_type, owner_id, period_start, tokens, cost, created_at, updated_at)
      SELECT 'Account', account_id, DATE_TRUNC('month', created_at)::date,
             SUM(total_tokens), SUM(cost), NOW(), NOW()
      FROM ai_usage_events
      GROUP BY account_id, DATE_TRUNC('month', created_at)::date
    SQL
  end

  def backfill_agency_counters
    execute <<~SQL.squish
      INSERT INTO ai_usage_counters (owner_type, owner_id, period_start, tokens, cost, created_at, updated_at)
      SELECT 'Agency', agency_id, DATE_TRUNC('month', created_at)::date,
             SUM(total_tokens), SUM(cost), NOW(), NOW()
      FROM ai_usage_events
      WHERE agency_id IS NOT NULL
      GROUP BY agency_id, DATE_TRUNC('month', created_at)::date
    SQL
  end
end
