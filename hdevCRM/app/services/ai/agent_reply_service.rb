module Ai
  # MIT chatbot layer: answers incoming customer messages with the account's
  # AI agent and hands the conversation off to a human when asked (or when
  # the AI token quota is exhausted).
  #
  # Account-level configuration (account.custom_attributes):
  #   'ai_agent_enabled'   => true/false
  #   'ai_agent_prompt'    => extra instructions appended to the system prompt
  #   'ai_agent_model'     => optional model override
  #   'ai_agent_inbox_ids' => optional allowlist of inbox ids (absent = all)
  #
  # Conversation-level state (conversation.custom_attributes):
  #   'ai_agent_handoff'   => true once a human takes over; the bot stays silent
  class AgentReplyService
    HANDOFF_MARKER = '[[HANDOFF]]'.freeze
    HISTORY_LIMIT = 20

    pattr_initialize [:conversation!]

    def self.enabled_for?(conversation)
      account = conversation.account
      return false unless truthy?(account.custom_attributes['ai_agent_enabled'])
      return false if conversation.resolved?
      return false if conversation.assignee_id.present?
      return false if truthy?(conversation.custom_attributes['ai_agent_handoff'])
      # Um fluxo de chatbot ativo conduz a conversa — sem isso, IA e fluxo respondem juntos.
      return false if ChatbotSession.active.exists?(conversation_id: conversation.id)

      inbox_allowed?(account, conversation.inbox_id)
    end

    def self.truthy?(value)
      ActiveRecord::Type::Boolean.new.cast(value) == true
    end

    def self.inbox_allowed?(account, inbox_id)
      inbox_ids = account.custom_attributes['ai_agent_inbox_ids']
      inbox_ids.blank? || inbox_ids.map(&:to_i).include?(inbox_id)
    end

    def perform
      return unless self.class.enabled_for?(conversation)

      messages = history_messages
      return if messages.blank?

      text = extract_text(ai_response(messages))
      return if text.blank?

      if text.include?(HANDOFF_MARKER)
        handoff!(reply_text: text.gsub(HANDOFF_MARKER, '').strip)
      else
        send_reply(text)
      end
    rescue Ai::QuotaExceededError
      handoff!(note: 'AI token quota exceeded — conversation handed off to a human agent.')
    end

    private

    def account
      conversation.account
    end

    def agency
      account.agency
    end

    def ai_response(messages)
      AnthropicService
        .new(account: account, feature: 'ai_agent', conversation: conversation)
        .chat(messages: messages, system: system_prompt, model: model)
    end

    def model
      account.custom_attributes['ai_agent_model'].presence || AnthropicService::DEFAULT_MODEL
    end

    def system_prompt
      base = <<~PROMPT
        You are a customer support assistant for #{brand_name}.
        Answer helpfully and concisely, in the customer's language.
        Never invent order numbers, prices or policies you were not given.
        If the customer asks for a human agent, or you cannot resolve the request,
        include the exact marker #{HANDOFF_MARKER} in your reply.
      PROMPT

      custom = account.custom_attributes['ai_agent_prompt'].presence
      [base, custom].compact.join("\n\n")
    end

    def brand_name
      agency&.global_config_overrides&.dig('BRAND_NAME').presence ||
        GlobalConfigService.load('BRAND_NAME', 'our team')
    end

    # Last N public messages, oldest first, mapped to Anthropic roles. The
    # Messages API requires the first message to be from the user, so leading
    # assistant messages (e.g. campaign greetings) are dropped.
    def history_messages
      records = conversation.messages
                            .where(message_type: [:incoming, :outgoing])
                            .where(private: false)
                            .order(created_at: :desc)
                            .limit(HISTORY_LIMIT)
                            .reverse

      records
        .filter_map { |message| { role: message.incoming? ? 'user' : 'assistant', content: message.content } if message.content.present? }
        .drop_while { |message| message[:role] != 'user' }
    end

    def extract_text(response)
      return if response.blank?

      Array(response.content)
        .filter_map { |block| block.text if block.respond_to?(:text) }
        .join("\n")
        .strip
    end

    def send_reply(text)
      return if text.blank?

      params = { content: text, private: false, content_attributes: { ai_agent: true } }
      Messages::MessageBuilder.new(nil, conversation, params).perform
    end

    def handoff!(reply_text: nil, note: nil)
      send_reply(reply_text) if reply_text.present?

      conversation.custom_attributes['ai_agent_handoff'] = true
      conversation.status = :open if conversation.pending?
      conversation.save!

      note_params = {
        content: note || 'AI agent handed this conversation off to a human.',
        private: true,
        content_attributes: { ai_agent: true }
      }
      Messages::MessageBuilder.new(nil, conversation.reload, note_params).perform
    end
  end
end
