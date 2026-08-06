class CreatePlanAiModels < ActiveRecord::Migration[7.1]
  # Decisão 1 do design (gate estrito + seed): join vazio = plano não libera
  # modelo nenhum. Pra nenhum plano existente mudar de comportamento no
  # deploy, todo plano nasce liberando o catálogo inteiro — o super admin
  # remove o que não quer depois.
  def up
    create_table :plan_ai_models do |t|
      t.references :plan, null: false, foreign_key: true
      t.references :ai_model, null: false, foreign_key: true
      t.timestamps
    end
    add_index :plan_ai_models, [:plan_id, :ai_model_id], unique: true

    execute <<~SQL.squish
      INSERT INTO plan_ai_models (plan_id, ai_model_id, created_at, updated_at)
      SELECT plans.id, ai_models.id, NOW(), NOW() FROM plans CROSS JOIN ai_models
    SQL
  end

  def down
    drop_table :plan_ai_models
  end
end
