class AiAgentListener < BaseListener
  def message_created(event)
    message = event.data[:message]
    return unless message.incoming?
    return if message.private?
    return unless Ai::AgentReplyService.enabled_for?(message.conversation)

    Ai::ReplyJob.perform_later(message.conversation_id)
  end
end
