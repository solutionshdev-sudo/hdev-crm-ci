class CreateChatbotSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :chatbot_sessions do |t|
      t.bigint :account_id, null: false
      t.bigint :chatbot_id, null: false
      t.bigint :conversation_id, null: false
      t.bigint :contact_id
      t.string :current_node_id
      t.integer :status, null: false, default: 0
      t.jsonb :variables, null: false, default: {}
      t.jsonb :context, null: false, default: {}
      t.integer :flow_version, null: false, default: 1
      t.datetime :expires_at
      t.datetime :last_activity_at
      t.string :last_error
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :chatbot_sessions, [:account_id, :status]
    add_index :chatbot_sessions, :expires_at, where: 'status IN (1, 2)'
    # Uma sessão ativa por conversa, garantida pelo banco (não por corrida no Ruby).
    add_index :chatbot_sessions, :conversation_id, unique: true, where: 'status IN (0, 1, 2)',
                                                   name: 'index_chatbot_sessions_active_unique'
    add_index :chatbot_sessions, :conversation_id
  end
end
