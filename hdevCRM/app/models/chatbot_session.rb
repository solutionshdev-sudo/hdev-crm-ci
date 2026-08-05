class ChatbotSession < ApplicationRecord
  belongs_to :account
  belongs_to :chatbot
  belongs_to :conversation
  belongs_to :contact, optional: true
  has_many :chatbot_session_events, dependent: :destroy_async

  enum :status, { running: 0, waiting_input: 1, waiting_delay: 2, completed: 3,
                  aborted: 4, handed_off: 5, failed: 6 }

  scope :active, -> { where(status: [:running, :waiting_input, :waiting_delay]) }

  after_update_commit :dispatch_flow_status_event, if: :saved_change_to_status?

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

  private

  # Cobre os 3 caminhos que levam a completed (end_node, run_loop, resume_job)
  # e o aborted de uma vez só, no lugar de duplicar o dispatch em cada um.
  def dispatch_flow_status_event
    event = { completed: CHATBOT_FLOW_COMPLETED, aborted: CHATBOT_FLOW_ABORTED }[status.to_sym]
    return if event.blank?

    Rails.configuration.dispatcher.dispatch(event, Time.zone.now, session: self, conversation: conversation, contact: contact)
  end
end
