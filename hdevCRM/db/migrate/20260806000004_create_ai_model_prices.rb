class CreateAiModelPrices < ActiveRecord::Migration[7.1]
  # Preço versionado: trocar preço = marcar superseded_at + inserir linha
  # nova, nunca update — AiUsageEvent antigo mantém o custo da época.
  # Cents inteiros por 1M de tokens: o custo vira múltiplo exato de 1e-8 USD.

  # USD/1M da constante Ai::Pricing::PRICES → cents/1M.
  PRICES_CENTS = {
    'claude-fable-5' => [1000, 5000],
    'claude-opus-5' => [500, 2500],
    'claude-opus-4-8' => [500, 2500],
    'claude-opus-4-7' => [500, 2500],
    'claude-opus-4-6' => [500, 2500],
    'claude-sonnet-5' => [300, 1500],
    'claude-sonnet-4-6' => [300, 1500],
    'claude-haiku-4-5' => [100, 500]
  }.freeze

  def up
    create_table :ai_model_prices do |t|
      t.references :ai_model, null: false, foreign_key: true
      t.integer :input_cents_per_million, null: false
      t.integer :output_cents_per_million, null: false
      t.integer :embedding_cents_per_million
      t.datetime :effective_from, null: false
      t.datetime :superseded_at
      t.timestamps
    end
    add_index :ai_model_prices, [:ai_model_id, :superseded_at]

    seed_prices
  end

  def down
    drop_table :ai_model_prices
  end

  private

  def seed_prices
    PRICES_CENTS.each do |canonical, (input_cents, output_cents)|
      execute <<~SQL.squish
        INSERT INTO ai_model_prices
          (ai_model_id, input_cents_per_million, output_cents_per_million, effective_from, created_at, updated_at)
        SELECT id, #{input_cents}, #{output_cents}, NOW(), NOW(), NOW()
        FROM ai_models WHERE canonical_id = '#{canonical}'
      SQL
    end
  end
end
