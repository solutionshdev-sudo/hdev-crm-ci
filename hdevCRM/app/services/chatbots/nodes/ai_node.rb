class Chatbots::Nodes::AiNode < Chatbots::Nodes::BaseNode
  # Desde a Fase 3b o nó roda o loop agêntico (Ai::ToolLoop, conjunto :agent
  # da Fase 3a), não um #chat solto: o modelo pode mover negócio, etiquetar,
  # atualizar contato e transferir a conversa, além de responder.
  #
  # Contexto de conversa/contato/variáveis JÁ chega ao system prompt por aqui:
  # `interpolate` roda o Chatbots::Interpolator, que resolve `{{contact.name}}`,
  # `{{contact.email}}`, `{{contact.phone_number}}`, `{{conversation.id}}`,
  # `{{inbox.name}}`, `{{account.name}}`, `{{now}}`, `{{vars.*}}` (=
  # session.variables) e `{{contact.custom_attributes.*}}` — allowlist já
  # existente. O autor do fluxo referencia essas chaves no prompt do nó; não
  # há bloco de contexto automático a mais para adicionar aqui.
  def execute
    # PARAR (Fase 2) é SEM AUTOMAÇÃO, não só sem mensagem: o loop roda cinco
    # tools de ESCRITA (mover negócio, etiquetar, atualizar contato,
    # transferir) antes de responder, e gasta quota — deixar rodar pra um
    # contato que pediu pra sair reescreveria cadastro/kanban/etiqueta de
    # quem não quer automação. Mesmo argumento e mesmo gate do
    # Ai::AgentReplyService.enabled_for? (ver comentário lá), aplicado aqui
    # porque o caminho do chatbot não herda aquele gate.
    return [:continue, next_or_default('handoff')] if Ai::AgentReplyService.automation_blocked?(conversation.contact)

    text = run_loop
    return [:continue, next_or_default('handoff')] if text.blank?

    handoff_requested?(text) ? handoff(text) : reply(text)
  rescue Ai::QuotaExceededError
    [:continue, next_or_default('handoff')]
  end

  private

  def run_loop
    @loop = Ai::ToolLoop.new(
      service: Ai::AnthropicService.new(account: conversation.account, feature: 'chatbot_node', conversation: conversation),
      registry: Ai::ToolRegistry.new(context: :agent, account: conversation.account, conversation: conversation),
      system_prompt: interpolate(data['prompt'].to_s)
    )
    @loop.run(messages: [{ role: 'user', content: user_content }])
  end

  # Handoff sai por dois portões independentes: o marcador de texto (existente
  # desde antes da 3b) OU a tool transferir_para_humano ter rodado no loop —
  # decidido por `executed`, nunca por reparse do texto. A tool já marcou
  # `ai_agent_handoff` e chamou `conversation.bot_handoff!`; deixar o fluxo
  # seguir pelo `'out'` faria a automação continuar numa conversa já entregue
  # ao humano.
  def handoff_requested?(text)
    text.include?(Ai::AgentReplyService::HANDOFF_MARKER) || transferred_to_human?
  end

  def transferred_to_human?
    @loop.executed.any? { |call| call[:name] == Ai::Tools::TransferirParaHumano.tool_name }
  end

  def handoff(text)
    clean_text = text.gsub(Ai::AgentReplyService::HANDOFF_MARKER, '').strip
    send_text(clean_text) if data['send_reply'] != false
    [:continue, next_or_default('handoff')]
  end

  def reply(text)
    session.variables[data['save_as']] = text if data['save_as'].present?
    send_text(text) if data['send_reply'] != false
    [:continue, next_or_default('out')]
  end

  # `reorder`, não `order`: Message tem default_scope de created_at ASC e um
  # `order` só SOMA no fim do ORDER BY — o desc era engolido e este nó mandava
  # ao modelo a mensagem mais ANTIGA da conversa (mesmo bug consertado no
  # Ai::AgentReplyService#history_messages na Fase 3a; as duas portas de entrada
  # de IA precisam ler a conversa do mesmo jeito).
  def user_content
    last_incoming = conversation.messages.incoming.where(private: false).reorder(created_at: :desc, id: :desc).first
    last_incoming&.content.presence || 'Olá'
  end
end
