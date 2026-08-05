class Chatbots::RunnerJob < MutexApplicationJob
  queue_as :medium
  retry_on LockAcquisitionError, wait: 2.seconds, attempts: 15

  def perform(session_id, message_id = nil)
    session = ChatbotSession.find_by(id: session_id)
    return if session.blank? || !session.active?

    message = session.conversation.messages.find_by(id: message_id) if message_id
    key = format(::Redis::Alfred::CHATBOT_SESSION_MUTEX, conversation_id: session.conversation_id)
    with_lock(key, 20.seconds) do
      Chatbots::ExecutionService.new(session: session, message: message).perform
    end
  end
end
