module Ai
  # Conjuntos de ferramentas por contexto. Cada conjunto é uma fronteira de
  # segurança, não uma categoria:
  #
  #   :agent   — roda em cima de mensagem de estranho (WhatsApp, widget). Só
  #              pode receber ferramenta de LEITURA. Uma tool de escrita aqui
  #              transforma prompt injection numa mensagem de cliente em
  #              alteração de dados da conta.
  #   :copilot — admin autenticado pedindo configuração. Pode escrever.
  #
  # Registry literal — nunca constantize string vinda do modelo.
  class ToolRegistry
    SETS = {
      agent: [].freeze,
      copilot: [
        Ai::Tools::CreateChatbotFlow,
        Ai::Tools::CreateDealPipeline,
        Ai::Tools::CreateLabels,
        Ai::Tools::SetBusinessHours,
        Ai::Tools::AssignChatbotToInbox
      ].freeze
    }.freeze

    class UnknownContextError < StandardError; end

    pattr_initialize [:context!, :account!, :user, :dry_run]

    # pattr_initialize gera readers privados; o ToolLoop precisa do account
    # para logar falha de iteração.
    public :account

    def tools
      @tools ||= classes.map { |klass| klass.new(account: account, user: user, dry_run: dry_run) }
    end

    # As classes carregam o schema neutro; quem embrulha no shape do provider
    # é o service.
    def tool_classes
      tools.map(&:class)
    end

    def find(name)
      tools.find { |tool| tool.class.tool_name == name }
    end

    private

    def classes
      SETS.fetch(context.to_sym) { raise UnknownContextError, "contexto de ferramentas desconhecido: #{context}" }
    end
  end
end
