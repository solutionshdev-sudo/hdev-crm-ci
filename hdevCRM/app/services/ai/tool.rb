module Ai
  # Base de toda ferramenta exposta ao LLM.
  #
  # O schema é JSON Schema puro e neutro de provider: cada service embrulha no
  # shape que sua API espera (Anthropic quer `input_schema`; OpenAI e Gemini
  # querem `function.parameters`). Declarar aqui uma vez é o que evita manter
  # duas definições quando entrar o segundo provider.
  #
  #   class MinhaTool < Ai::Tool
  #     declare name: 'fazer_algo', description: '...', schema: { ... }
  #     def call(input) = 'resultado em texto'
  #   end
  class Tool
    class << self
      attr_reader :tool_name, :tool_description, :tool_schema

      # `strict` só pode ser ligado quando o schema é totalmente fechado
      # (`additionalProperties: false` em todo objeto). Schema com campo
      # livre precisa ficar false, ou a API rejeita a definição.
      def tool_strict = @tool_strict || false

      def declare(name:, description:, schema:, strict: false)
        @tool_name = name
        @tool_description = description
        @tool_schema = schema
        @tool_strict = strict
      end
    end

    pattr_initialize [:account!, :user]

    # Recebe o input já parseado e devolve String — o texto vira o tool_result
    # que o modelo lê. Erro previsível deve virar Ai::ToolError.
    def call(_input)
      raise NotImplementedError
    end
  end
end
