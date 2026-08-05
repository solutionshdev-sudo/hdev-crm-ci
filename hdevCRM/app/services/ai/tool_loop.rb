module Ai
  # Loop agêntico neutro de provider: pede ao modelo, executa as ferramentas que
  # ele chamou, devolve os resultados e repete até ele parar de chamar.
  #
  # O service (Anthropic hoje; OpenAI/Gemini depois) implementa quatro seams:
  #   #raw_chat          — faz a chamada, checa quota e grava AiUsageEvent
  #   #parse_turn        — resposta nativa -> Turn
  #   #assistant_turn    — resposta nativa -> mensagem pra reenviar no histórico
  #   #tool_result_turn  — resultados -> mensagens pra reenviar no histórico
  #
  # Quota e contabilização de tokens vivem dentro de #raw_chat, chamado uma vez
  # por iteração — é o que impede um loop de ferramentas de furar o limite.
  class ToolLoop
    # Teto de segurança: modelo teimoso chamando ferramenta em círculo para aqui.
    MAX_ITERATIONS = 8

    Turn = Struct.new(:text, :tool_calls, keyword_init: true)
    Call = Struct.new(:id, :name, :input, keyword_init: true)
    Result = Struct.new(:id, :content, :error, keyword_init: true)

    # `system_prompt`, não `system`: um reader chamado `system` sombrearia
    # Kernel#system dentro da classe.
    pattr_initialize [:service!, :registry!, :system_prompt, :model, :max_tokens]

    # Chamadas que rodaram sem erro, na ordem. O copiloto reexecuta essa lista
    # na hora de aplicar — é o que dispensa uma segunda ida ao modelo.
    def executed
      @executed ||= []
    end

    # Devolve o último texto que o modelo produziu.
    def run(messages:)
      history = messages.dup
      text = nil

      MAX_ITERATIONS.times do
        response = call_model(history)
        turn = service.parse_turn(response)
        text = turn.text.presence || text
        return text if turn.tool_calls.blank?

        history << service.assistant_turn(response)
        history.concat(service.tool_result_turn(execute(turn.tool_calls)))
      end

      Rails.logger.warn("[AI TOOL] loop parou em MAX_ITERATIONS (account=#{registry.account.id})")
      text
    end

    private

    def call_model(history)
      params = { messages: history, system: system_prompt, tools: registry.tool_classes }
      params[:model] = model if model.present?
      params[:max_tokens] = max_tokens if max_tokens.present?
      service.raw_chat(**params)
    end

    def execute(calls)
      calls.map { |call| execute_one(call) }
    end

    def execute_one(call)
      tool = registry.find(call.name)
      return Result.new(id: call.id, content: "Ferramenta desconhecida: #{call.name}", error: true) if tool.nil?

      content = tool.perform(call.input).to_s
      executed << { name: call.name, input: call.input, result: content }
      Result.new(id: call.id, content: content, error: false)
    rescue Ai::ToolError => e
      Result.new(id: call.id, content: e.message, error: true)
    rescue StandardError => e
      # Mensagem genérica de propósito: o texto volta pro modelo (e pode chegar
      # ao cliente final), então detalhe interno não sai daqui.
      Rails.logger.error("[AI TOOL] #{call.name} falhou: #{e.class} #{e.message}")
      Result.new(id: call.id, content: 'Erro interno ao executar a ferramenta.', error: true)
    end
  end
end
