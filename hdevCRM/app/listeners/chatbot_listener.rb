class ChatbotListener < BaseListener
  def message_created(event)
    message = event.data[:message]
    return unless message.incoming?
    return if message.private?
    # anti-loop: mensagens do próprio fluxo também disparam message_created
    return if message.content_attributes&.dig('chatbot_id').present?

    conversation = message.conversation
    session = ChatbotSession.active.find_by(conversation_id: conversation.id)
    if session
      Chatbots::RunnerJob.perform_later(session.id, message.id)
    else
      Chatbots::TriggerService.new(conversation: conversation, message: message).perform
    end
  end
end
