class CreateChatbotInboxes < ActiveRecord::Migration[7.1]
  def change
    create_table :chatbot_inboxes do |t|
      t.bigint :chatbot_id, null: false
      t.bigint :inbox_id, null: false
      t.timestamps
    end
    add_index :chatbot_inboxes, [:chatbot_id, :inbox_id], unique: true
    add_index :chatbot_inboxes, :inbox_id
  end
end
