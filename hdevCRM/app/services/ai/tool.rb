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

    # `conversation` é opcional: só as tools do set `:agent` (task 2+) recebem
    # — é o escopo injetado pelo runtime, nunca um id vindo do modelo. Reader
    # fica privado (pattr_initialize já gera assim) — é a própria tool que usa.
    pattr_initialize [:account!, :user, :dry_run, :conversation]

    # Recebe o input já parseado e devolve String — o texto vira o tool_result
    # que o modelo lê. Erro previsível deve virar Ai::ToolError.
    def call(_input)
      raise NotImplementedError
    end

    # Ponto de entrada do loop. Em `dry_run` a ferramenta roda de verdade e o
    # banco é desfeito no fim: a validação é a real, sem nenhuma tool precisar
    # saber que está em preview. É isso que permite propor e aplicar com uma
    # definição só.
    #
    # `requires_new` é obrigatório: sem savepoint, o ActiveRecord::Rollback é
    # engolido quando já existe transação aberta (o caso dos specs) e a
    # gravação vazaria.
    #
    # ponytail: savepoint por chamada, não por turno — no preview uma ferramenta
    # não enxerga o que a anterior criou (criar chatbot e vincular à inbox no
    # mesmo turno falha ao propor e funciona ao aplicar). Um savepoint por turno
    # resolveria, mas levaria junto o AiUsageEvent e furaria a quota; o conserto
    # é acumular o usage e regravar depois do rollback.
    #
    # ponytail: o savepoint desfaz o banco, não job enfileirado em after_create.
    # As ferramentas de hoje só gravam. Revisar ao adicionar tool que dispare job.
    def perform(input)
      return call(input) unless dry_run

      result = nil
      ActiveRecord::Base.transaction(requires_new: true) do
        result = call(input)
        raise ActiveRecord::Rollback
      end
      result
    end

    private

    # Erro de validação vira Ai::ToolError: o texto volta pro modelo como
    # tool_result de erro e ele corrige na iteração seguinte.
    def persist!(record)
      return record if record.save

      raise Ai::ToolError, record.errors.full_messages.join('; ').presence || 'Não foi possível salvar.'
    end
  end
end
