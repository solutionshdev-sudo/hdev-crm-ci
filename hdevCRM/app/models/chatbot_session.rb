class ChatbotSession < ApplicationRecord
  belongs_to :account
  belongs_to :chatbot
  belongs_to :conversation
  belongs_to :contact, optional: true
  has_many :chatbot_session_events, dependent: :destroy_async

  enum :status, { running: 0, waiting_input: 1, waiting_delay: 2, completed: 3,
                  aborted: 4, handed_off: 5, failed: 6 }

  scope :active, -> { where(status: [:running, :waiting_input, :waiting_delay]) }

  def active?
    running? || waiting_input? || waiting_delay?
  end

  def log_event(event_type, node: nil, data: {})
    chatbot_session_events.create!(
      account_id: account_id,
      node_id: node&.dig('id'),
      node_type: node&.dig('type'),
      event_type: event_type,
      data: data
    )
  end
end
