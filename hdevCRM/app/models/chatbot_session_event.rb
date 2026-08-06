# Log append-only da execução do fluxo (sem updated_at) — debug e "caminho
# percorrido" no canvas.
class ChatbotSessionEvent < ApplicationRecord
  belongs_to :chatbot_session
  belongs_to :account

  enum :event_type, { entered: 0, completed: 1, failed: 2, timed_out: 3, input_received: 4 }
end
