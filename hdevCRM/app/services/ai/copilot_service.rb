module Ai
  # Copiloto de configuração: o admin pede em linguagem natural, o modelo
  # propõe, o admin confirma na tela, o Rails aplica.
  #
  # Propor e aplicar usam as MESMAS ferramentas. Em #propose elas rodam de
  # verdade dentro de um savepoint desfeito (Ai::Tool#perform), então a
  # validação do preview é a real e nenhuma tool precisa de código de preview.
  # #apply reexecuta as chamadas gravadas, sem passar pelo modelo de novo.
  #
  # Fronteira de segurança: contexto :copilot (tools de escrita) só existe aqui,
  # atrás de check_admin_authorization?. Escopo travado no account recebido —
  # nenhuma tool aceita account_id como parâmetro.
  class CopilotService
    # Tarefa difícil (propor mudança estrutural sem errar id), vale o modelo caro.
    # No Opus 5 o thinking vem ligado por padrão e divide o max_tokens com a
    # resposta — daí o teto folgado.
    MODEL = 'claude-opus-5'.freeze
    MAX_TOKENS = 8192
    ROLES = %w[user assistant].freeze

    class UnknownChangeError < StandardError; end

    pattr_initialize [:account!, :user!]

    # => { reply: String, changes: [{ name:, input:, result: }] }
    def propose(messages)
      runner = Ai::ToolLoop.new(
        service: Ai::AnthropicService.new(account: account, feature: 'copilot'),
        registry: registry(dry_run: true),
        system_prompt: system_prompt,
        model: MODEL,
        max_tokens: MAX_TOKENS
      )

      { reply: runner.run(messages: normalize(messages)), changes: runner.executed }
    end

    # Tudo ou nada: uma mudança inválida no meio não deixa metade gravada.
    def apply(changes)
      applied = registry(dry_run: false)

      ActiveRecord::Base.transaction do
        Array(changes).map do |change|
          change = change.to_h.with_indifferent_access
          tool = applied.find(change[:name].to_s)
          raise UnknownChangeError, I18n.t('errors.api.copilot.unknown_change', name: change[:name]) if tool.nil?

          tool.perform((change[:input] || {}).to_h)
        end
      end
    end

    private

    def registry(dry_run:)
      Ai::ToolRegistry.new(context: :copilot, account: account, user: user, dry_run: dry_run)
    end

    # A API exige papéis conhecidos e conteúdo não vazio; o cliente é o
    # navegador do admin, mas ainda é uma fronteira.
    def normalize(messages)
      Array(messages).filter_map do |message|
        message = message.to_h.with_indifferent_access
        next unless ROLES.include?(message[:role].to_s) && message[:content].present?

        { role: message[:role].to_s, content: message[:content].to_s }
      end
    end

    def system_prompt
      <<~PROMPT
        Você é o copiloto de configuração do #{brand_name}, um CRM de atendimento.
        Quem fala com você é um administrador configurando a conta dele.

        Use as ferramentas para propor as mudanças. NADA é gravado até o
        administrador confirmar na tela, então não diga que já está feito:
        descreva em uma frase curta o que será criado e peça a confirmação.

        Nunca invente ids — use apenas os que aparecem abaixo. Se o usuário citar
        algo que não está na lista, diga que não encontrou em vez de chutar.

        Configuração atual da conta:
        #{snapshot}
      PROMPT
    end

    def snapshot
      [
        "- Caixas de entrada: #{listing(account.inboxes.map { |inbox| "#{inbox.id} #{inbox.name} (#{inbox.channel_type})" })}",
        "- Chatbots: #{listing(account.chatbots.map { |bot| "#{bot.id} #{bot.name} (#{bot.status})" })}",
        "- Funis: #{listing(account.deal_pipelines.map { |funnel| "#{funnel.id} #{funnel.name}" })}",
        "- Etiquetas: #{listing(account.labels.pluck(:title))}"
      ].join("\n")
    end

    def listing(items)
      items.presence&.join('; ') || 'nenhum'
    end

    def brand_name
      GlobalConfigService.load('BRAND_NAME', 'HDEV CRM')
    end
  end
end
