class CreateChatbotSessionEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :chatbot_session_events do |t|
      t.bigint :chatbot_session_id, null: false
      t.bigint :account_id, null: false
      t.string :node_id
      t.string :node_type
      t.integer :event_type, null: false, default: 0
      t.jsonb :data, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :chatbot_session_events, [:chatbot_session_id, :id]
    add_index :chatbot_session_events, [:account_id, :created_at]
  end
end
