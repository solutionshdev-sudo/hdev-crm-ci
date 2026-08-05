module Ai
  class ReplyJob < ApplicationJob
    queue_as :default

    def perform(conversation_id)
      conversation = Conversation.find_by(id: conversation_id)
      return if conversation.blank?

      Ai::AgentReplyService.new(conversation: conversation).perform
    end
  end
end
