class CreateAiModels < ActiveRecord::Migration[7.1]
  # canonical_id é o que a UI mostra e o AiUsageEvent grava; provider_model_id
  # é o que vai no wire. É essa separação que faz Bedrock ser troca de conexão
  # + update de provider_model_id, sem tocar em conta nenhuma.

  # Os 8 modelos da constante Ai::Pricing::PRICES (lib/ai/pricing.rb) em
  # 06/08/2026. Modality direct: provider_model_id == canonical_id.
  CATALOG = [
    ['claude-fable-5',    'Claude Fable 5',    false],
    ['claude-opus-5',     'Claude Opus 5',     false],
    ['claude-opus-4-8',   'Claude Opus 4.8',   false],
    ['claude-opus-4-7',   'Claude Opus 4.7',   false],
    ['claude-opus-4-6',   'Claude Opus 4.6',   false],
    ['claude-sonnet-5',   'Claude Sonnet 5',   false],
    ['claude-sonnet-4-6', 'Claude Sonnet 4.6', false],
    ['claude-haiku-4-5',  'Claude Haiku 4.5',  true]
  ].freeze

  def up
    create_table :ai_models do |t|
      t.string :canonical_id, null: false
      t.string :provider_model_id, null: false
      t.references :ai_connection, null: false, foreign_key: true
      t.string :display_name, null: false
      t.string :description
      t.integer :context_window
      t.boolean :supports_tools, null: false, default: true
      t.boolean :default_for_provider, null: false, default: false
      t.datetime :deprecated_at
      t.timestamps
    end
    add_index :ai_models, :canonical_id, unique: true

    seed_catalog
  end

  def down
    drop_table :ai_models
  end

  private

  def seed_catalog
    CATALOG.each do |canonical, display, default|
      execute <<~SQL.squish
        INSERT INTO ai_models
          (canonical_id, provider_model_id, ai_connection_id, display_name, default_for_provider, created_at, updated_at)
        SELECT '#{canonical}', '#{canonical}', id, '#{display}', #{default}, NOW(), NOW()
        FROM ai_connections WHERE provider = 0 AND modality = 0 AND label = 'Anthropic API'
      SQL
    end
  end
end
