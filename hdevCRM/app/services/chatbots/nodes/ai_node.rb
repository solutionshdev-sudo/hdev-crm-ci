class Chatbots::Nodes::AiNode < Chatbots::Nodes::BaseNode
  def execute
    text = ai_reply
    return [:continue, next_or_default('handoff')] if text.blank?

    if text.include?(Ai::AgentReplyService::HANDOFF_MARKER)
      send_text(text.gsub(Ai::AgentReplyService::HANDOFF_MARKER, '').strip) if data['send_reply'] != false
      return [:continue, next_or_default('handoff')]
    end

    session.variables[data['save_as']] = text if data['save_as'].present?
    send_text(text) if data['send_reply'] != false
    [:continue, next_or_default('out')]
  rescue Ai::QuotaExceededError
    [:continue, next_or_default('handoff')]
  end

  private

  def ai_reply
    response = Ai::AnthropicService
               .new(account: conversation.account, feature: 'chatbot_node', conversation: conversation)
               .chat(messages: [{ role: 'user', content: user_content }], system: interpolate(data['prompt'].to_s))
    Array(response&.content).filter_map { |block| block.text if block.respond_to?(:text) }.join("\n").strip
  end

  def user_content
    last_incoming = conversation.messages.incoming.where(private: false).order(created_at: :desc).first
    last_incoming&.content.presence || 'Olá'
  end
end
