# Decides whether an incoming message/conversation starts a chatbot session,
# and creates it. The unique partial index on chatbot_sessions guarantees one
# active session per conversation even under concurrent webhooks.
class Chatbots::TriggerService
  pattr_initialize [:conversation!, :message]

  def perform
    return unless should_trigger?

    session = create_session
    return if session.blank?

    conversation.update!(status: :pending) if conversation.open? && conversation.assignee_id.nil?
    Chatbots::RunnerJob.perform_later(session.id, message&.id)
  end

  private

  def chatbot
    @chatbot ||= conversation.inbox.active_chatbot
  end

  def should_trigger?
    return false if chatbot.blank?
    return false if conversation.resolved?
    return false if conversation.assignee_id.present?
    # Qualquer sessão (ativa OU terminada) bloqueia novo disparo na conversa —
    # senão o bot sequestra conversa que já passou por handoff.
    return false if ChatbotSession.exists?(conversation_id: conversation.id)
    return false unless keyword_match?

    true
  end

  # keyword_triggers vazio = dispara em qualquer primeira mensagem.
  def keyword_match?
    keywords = Array(chatbot.settings['keyword_triggers']).compact_blank
    return true if keywords.blank?
    return false if message.blank?

    content = message.content.to_s.downcase
    keywords.any? { |keyword| content.include?(keyword.downcase) }
  end

  def create_session
    start = chatbot.start_node
    return if start.blank?

    chatbot.chatbot_sessions.create!(
      account_id: conversation.account_id,
      conversation_id: conversation.id,
      contact_id: conversation.contact_id,
      current_node_id: start['id'],
      status: :running,
      flow_version: chatbot.flow_version
    )
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
