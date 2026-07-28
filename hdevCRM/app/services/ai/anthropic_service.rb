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
    # Haiku dá conta de FAQ/triagem por 1/5 do preço do Opus. Tarefa difícil
    # (gerar fluxo, copiloto admin) passa o modelo explicitamente.
    DEFAULT_MODEL = 'claude-haiku-4-5'.freeze
    DEFAULT_MAX_TOKENS = 1024

    pattr_initialize [:account!, :feature, :conversation]

    def chat(messages:, system: nil, model: DEFAULT_MODEL, max_tokens: DEFAULT_MAX_TOKENS)
      raw_chat(messages: messages, system: system, model: model, max_tokens: max_tokens)
    end

    # --- Seams do Ai::ToolLoop -------------------------------------------
    # Os quatro métodos abaixo são o contrato que o loop agêntico consome. O
    # service OpenAI/Gemini implementa os mesmos quatro com a tradução dele.

    # Quota e AiUsageEvent ficam aqui, e o loop chama isso uma vez por
    # iteração — é o que impede tool calling de furar o limite mensal.
    def raw_chat(messages:, system: nil, tools: nil, model: DEFAULT_MODEL, max_tokens: DEFAULT_MAX_TOKENS)
      raise Ai::QuotaExceededError, 'AI token quota exceeded' if QuotaService.new(account: account).exceeded?

      params = { model: model, max_tokens: max_tokens, messages: messages }
      params[:system] = system if system.present?
      params[:tools] = tools.map { |tool_class| tool_definition(tool_class) } if tools.present?

      response = client.messages.create(**params)
      record_usage(model, response)
      response
    end

    def parse_turn(response)
      blocks = Array(response&.content)
      Ai::ToolLoop::Turn.new(
        text: blocks.select { |block| block_type(block) == 'text' }.map(&:text).join("\n").strip,
        tool_calls: blocks.select { |block| block_type(block) == 'tool_use' }.map do |block|
          Ai::ToolLoop::Call.new(id: block.id, name: block.name.to_s, input: block.input.to_h)
        end
      )
    end

    # Reenviar os blocos crus preserva os tool_use — reconstruir só o texto
    # quebra o pareamento com os tool_result da mensagem seguinte.
    def assistant_turn(response)
      { role: 'assistant', content: Array(response.content).map { |block| block.deep_to_h } }
    end

    # Todos os resultados vão numa ÚNICA mensagem de user: dividir em várias
    # ensina o modelo a parar de chamar ferramentas em paralelo.
    def tool_result_turn(results)
      content = results.map do |result|
        { type: 'tool_result', tool_use_id: result.id, content: result.content, is_error: result.error }
      end
      [{ role: 'user', content: content }]
    end

    private

    # Anthropic quer {name, description, input_schema}; OpenAI e Gemini querem
    # {type: 'function', function: {name, description, parameters}}. O schema
    # nasce neutro em Ai::Tool e é embrulhado aqui.
    def tool_definition(tool_class)
      definition = {
        name: tool_class.tool_name,
        description: tool_class.tool_description,
        input_schema: tool_class.tool_schema
      }
      definition[:strict] = true if tool_class.tool_strict
      definition
    end

    def block_type(block)
      block.type.to_s
    end

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
