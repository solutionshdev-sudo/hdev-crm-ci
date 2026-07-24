module Ai
  # MIT-licensed AI layer over the official Anthropic SDK. Every call is
  # gated by the per-account/per-agency quota and recorded in
  # ai_usage_events with its token usage and computed cost.
  #
  # Usage:
  #   Ai::AnthropicService.new(account: account, feature: 'chatbot').chat(
  #     messages: [{ role: 'user', content: 'Olá' }],
  #     system: 'Você é um atendente...'
  #   )
  class AnthropicService
    DEFAULT_MODEL = 'claude-opus-4-8'.freeze
    DEFAULT_MAX_TOKENS = 1024

    pattr_initialize [:account!, :feature, :conversation]

    def chat(messages:, system: nil, model: DEFAULT_MODEL, max_tokens: DEFAULT_MAX_TOKENS)
      raise Ai::QuotaExceededError, 'AI token quota exceeded' if QuotaService.new(account: account).exceeded?

      params = { model: model, max_tokens: max_tokens, messages: messages }
      params[:system] = system if system.present?

      response = client.messages.create(**params)
      record_usage(model, response)
      response
    end

    private

    def client
      @client ||= Anthropic::Client.new(api_key: api_key)
    end

    def api_key
      GlobalConfigService.load('ANTHROPIC_API_KEY', nil)
    end

    def record_usage(model, response)
      AiUsageEvent.record!(
        account: account,
        model: model,
        input_tokens: response.usage.input_tokens,
        output_tokens: response.usage.output_tokens,
        feature: feature,
        conversation: conversation
      )
    end
  end
end
