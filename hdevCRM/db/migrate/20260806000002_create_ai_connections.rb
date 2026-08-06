class CreateAiConnections < ActiveRecord::Migration[7.1]
  # F8: credencial de IA é assunto exclusivo do super admin. api_key nasce
  # NULL de propósito — enquanto o painel não recebe a chave, o runtime cai
  # no GlobalConfigService (ANTHROPIC_API_KEY da env), então o deploy não
  # move segredo e a IA não para (design doc, decisão 3).
  def up
    create_table :ai_connections do |t|
      t.integer :provider, null: false, default: 0
      t.integer :modality, null: false, default: 0
      t.string :label, null: false
      t.text :api_key
      t.string :region
      t.text :aws_access_key_id
      t.text :aws_secret_access_key
      t.datetime :validated_at
      t.string :validation_error
      t.jsonb :models_available, null: false, default: {}
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :ai_connections, [:provider, :modality, :label], unique: true

    execute <<~SQL.squish
      INSERT INTO ai_connections (provider, modality, label, created_at, updated_at)
      VALUES (0, 0, 'Anthropic API', NOW(), NOW())
    SQL
  end

  def down
    drop_table :ai_connections
  end
end
