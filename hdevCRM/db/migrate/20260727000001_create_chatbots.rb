class CreateChatbots < ActiveRecord::Migration[7.1]
  def change
    create_table :chatbots do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.string :description
      t.integer :status, null: false, default: 0
      # Formato nativo do Vue Flow: {version, viewport, nodes[], edges[]}.
      t.jsonb :flow, null: false, default: {}
      t.jsonb :settings, null: false, default: {}
      t.integer :flow_version, null: false, default: 1
      t.bigint :created_by_id
      t.bigint :updated_by_id
      t.timestamps
    end
    add_index :chatbots, [:account_id, :status]
  end
end
