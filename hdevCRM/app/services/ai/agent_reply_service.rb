module Ai
  # MIT chatbot layer: answers incoming customer messages with the account's
  # AI agent and hands the conversation off to a human when asked (or when
  # the AI token quota is exhausted).
  #
  # Desde a Fase 3a o agente não é só conversador: ele roda o Ai::ToolLoop com
  # o conjunto :agent de ferramentas (mover negócio, criar negócio, atualizar
  # contato, etiquetar, transferir), todas escopadas NESTA conversa.
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

    # Pedido explícito de humano, detectado ANTES de chamar o modelo: handoff
    # de custo zero, sem AnthropicService e sem AiUsageEvent.
    #
    # Conservador é o requisito, não a cobertura: falso positivo cala o bot à
    # toa (a flag de handoff não volta sozinha), enquanto falso negativo ainda
    # é pego pelo HANDOFF_MARKER que o modelo emite — a segunda rede.
    #
    # Por isso exige VERBO + ALVO, com uma lista FECHADA de palavras de
    # ligação entre os dois: "quero falar com um atendente" casa; "meu
    # atendente favorito resolveu" não (alvo sem verbo antes), e "quero saber
    # do meu pedido" também não ("saber" não está na lista de ligação, então a
    # janela não estica por cima de qualquer palavra).
    #
    # Os verbos entram por dois portões diferentes, e é isso que separa pedido
    # de elogio:
    #
    #   - verbo de AÇÃO (falar, passar, transferir...) só vale ABRINDO oração —
    #     início da mensagem, depois de pontuação/quebra de linha, ou depois de
    #     pronome ("me passa"). Sem esse portão, "adorei falar com o atendente
    #     de vocês" e "gostei de falar com a pessoa que me atendeu" — elogios de
    #     pós-atendimento — calavam o bot pro resto da conversa.
    #   - verbo de DESEJO (quero, preciso, gostaria, desejo) vale em qualquer
    #     posição, porque já carrega o pedido: "bom dia quero falar com um
    #     atendente" precisa casar mesmo sem vírgula.
    #
    # "pessoa" é ALVO FRACO e por isso tem janela PRÓPRIA, mais curta: é
    # substantivo comum, não palavra de atendimento, e enche a caixa de um CRM
    # vendido pra agência ("quero ser pessoa jurídica", "preciso de uma pessoa
    # para assinar o contrato", "quero uma pessoa de contato no comercial").
    # Só conta quando alcançado ATRAVÉS de uma palavra de contato
    # (com/pra/para/pro/falar/conversar/atendido/atendida/atendimento) e no
    # máximo dois determinantes depois dela. "atendente|humano|humana|alguém"
    # continuam com a janela larga: ninguém escreve essas palavras a não ser
    # falando de atendimento.
    #
    # Pela mesma razão "ser" saiu da lista de ligação solta e só volta colado em
    # "atendido/atendida": "quero ser atendido por um humano" é pedido, "quero
    # ser pessoa jurídica" é cadastro.
    #
    # O QUE ESSE DESENHO CUSTA, por inteiro — a lista, não um exemplo: exigir
    # que o verbo de ação abra oração derruba as formas polidas e
    # interrogativas, que são perto de um terço do jeito natural de pedir humano
    # em pt-BR ("tem como falar com um atendente?", "consigo falar com alguém?",
    # "por favor transferir para atendente", "posso falar com um atendente?"), e
    # a lista fechada de ligação derruba quem enfia advérbio no meio ("preciso
    # urgente falar com um humano"). Nenhuma delas some do produto: o turno
    # segue pro modelo e o HANDOFF_MARKER é a rede que as pega — custam uma
    # chamada de IA, que é o lado barato do trade.
    #
    # Sem normalizador de acento: o /i resolve a caixa e a vogal acentuada
    # entra como alternativa no próprio padrão — mesmo desenho do OPT_OUT_REGEX
    # em app/services/whatsapp/incoming_message_service_helpers.rb.
    HANDOFF_REQUEST_REGEX = /
      (?:
        (?:\A\s*|[.!?,;:\n]\s*|\b(?:eu|vc|voc[eê]|me)\s+)
        \b(?:falar|conversar|cham(?:a|ar|e)|pass(?:a|ar|e)|
             transfer(?:e|ir|a)|encaminh(?:a|ar|e))\b
        |
        \b(?:quer(?:o|ia)|precis(?:o|ava)|gostaria|desejo)\b
      )
      \s+
      (?:\b(?:com|de|pra|para|pro|por|me|um|uma|o|a|algum|alguma|outro|outra|
              falar|conversar|atendido|atendida|atendimento|ser\s+atendid[oa])\s+){0,5}
      (?:
        \b(?:atendente|humano|humana|algu[eé]m)\b
        |
        \b(?:com|pra|para|pro|falar|conversar|atendido|atendida|atendimento)\s+
        (?:\b(?:um|uma|o|a|outro|outra|algum|alguma)\s+){0,2}
        \bpessoa\b
      )
    /xi

    # Negativa colada no verbo derruba o pedido: "não quero falar com
    # atendente" casaria pelo "falar com atendente" que sobra no meio.
    #
    # O padrão exige o verbo imediatamente depois do "não", mas o VETO é da
    # MENSAGEM INTEIRA: "não quero esperar, quero falar com um atendente" é
    # suprimida por completo. Fica assim de propósito — falso negativo é o lado
    # barato e o HANDOFF_MARKER cobre. "não recebi o pedido, quero falar com
    # atendente" continua sendo handoff, porque "recebi" não está na lista.
    HANDOFF_DENIAL_REGEX = /\bn[aã]o\s+(?:quero|queria|preciso|precisava|gostaria|desejo)\b/i

    pattr_initialize [:conversation!]

    def self.enabled_for?(conversation)
      account = conversation.account
      return false unless truthy?(account.custom_attributes['ai_agent_enabled'])
      return false if conversation.resolved?
      return false if conversation.assignee_id.present?
      return false if truthy?(conversation.custom_attributes['ai_agent_handoff'])
      # Um fluxo de chatbot ativo conduz a conversa — sem isso, IA e fluxo respondem juntos.
      return false if ChatbotSession.active.exists?(conversation_id: conversation.id)
      return false if automation_blocked?(conversation.contact)

      inbox_allowed?(account, conversation.inbox_id)
    end

    # "PARAR" (Fase 2) significa SEM AUTOMAÇÃO, não só "sem mensagem enviada".
    # O gate de opt-out mora na camada de envio (Base::SendOnChannelService e
    # Messaging::SendGateService) e até a Fase 3a isso bastava: o agente compunha
    # um texto que era retido lá, sem efeito visível. Desde a F3a o mesmo turno
    # roda CINCO ferramentas de ESCRITA antes de responder — deixar rodar
    # reescreveria o cadastro do contato, aplicaria etiqueta, criaria negócio no
    # kanban e transferiria a conversa de quem pediu explicitamente pra sair da
    # automação, queimando quota, e ele não receberia nada de volta. Por isso o
    # gate sobe pra cá, antes do modelo.
    #
    # `blocked?` entra junto pelo mesmo motivo e é o par que a camada de envio
    # já usa (contact.automation_opted_out? || contact.blocked?).
    def self.automation_blocked?(contact)
      return false if contact.nil?

      contact.automation_opted_out? || contact.blocked?
    end

    def self.truthy?(value)
      ActiveRecord::Type::Boolean.new.cast(value) == true
    end

    def self.inbox_allowed?(account, inbox_id)
      inbox_ids = account.custom_attributes['ai_agent_inbox_ids']
      inbox_ids.blank? || inbox_ids.map(&:to_i).include?(inbox_id)
    end

    # Único ponto de handoff do agente de IA: o #handoff! daqui e a ferramenta
    # Ai::Tools::TransferirParaHumano entram os dois por aqui. As duas pontas
    # precisam do MESMO par de efeitos e bloco duplicado desalinha na primeira
    # mudança.
    #
    #   1. a flag em custom_attributes é o que cala o bot (ver .enabled_for?);
    #   2. conversation#bot_handoff! reabre a conversa e dispara
    #      CONVERSATION_BOT_HANDOFF no barramento — o mesmo caminho do
    #      Chatbots::Nodes::HandoffNode, que fila/notificação/automação já
    #      entendem.
    #
    # Idempotente de propósito: se o modelo chamar a ferramenta E devolver o
    # HANDOFF_MARKER no mesmo turno, o evento sai UMA vez só.
    def self.handoff!(conversation)
      return false if truthy?(conversation.custom_attributes['ai_agent_handoff'])

      conversation.custom_attributes['ai_agent_handoff'] = true
      conversation.save!
      conversation.bot_handoff!
      true
    end

    def perform
      return unless self.class.enabled_for?(conversation)
      return handoff!(note: 'Customer asked for a human agent — handed off before calling the AI.') if human_requested?

      messages = history_messages
      deliver(ai_response(messages)) if messages.present?
    rescue Ai::QuotaExceededError
      handoff!(note: 'AI token quota exceeded — conversation handed off to a human agent.')
    end

    private

    # Texto final do loop: o marcador vira handoff, o resto sai pro cliente
    # pelo caminho normal de envio.
    def deliver(text)
      return if text.blank?

      if text.include?(HANDOFF_MARKER)
        handoff!(reply_text: text.gsub(HANDOFF_MARKER, '').strip)
      else
        send_reply(text)
      end
    end

    def account
      conversation.account
    end

    def agency
      account.agency
    end

    # Só UMA mensagem recebida, nunca o histórico inteiro: varrer tudo faria um
    # "quero falar com atendente" de dez trocas atrás transferir a conversa hoje.
    #
    # Qual mensagem, com precisão: a incoming pública MAIS RECENTE no momento em
    # que o job roda — não a que disparou o turno. O Ai::ReplyJob recebe
    # `conversation_id`, não id de mensagem, então se o cliente escrever duas
    # vezes seguidas antes do job pegar, é a segunda que é lida. É o
    # comportamento desejado (a última palavra do cliente é a que vale), mas o
    # contrato é esse, e não "a mensagem que disparou".
    #
    # `reorder`, não `order`: Message tem default_scope de created_at ASC e um
    # `order` só SOMA no fim do ORDER BY — o desc seria engolido e isso aqui
    # leria a mensagem mais ANTIGA (ver comentário no topo de message.rb).
    def human_requested?
      content = conversation.messages.incoming.where(private: false).reorder(created_at: :desc, id: :desc).pick(:content).to_s
      content.match?(HANDOFF_REQUEST_REGEX) && !content.match?(HANDOFF_DENIAL_REGEX)
    end

    # O agente roda o LOOP agêntico, não um chat solto — é o que o transforma
    # de conversador em operador (move negócio, etiqueta, transfere). Quota e
    # AiUsageEvent continuam exatamente onde estavam, dentro do #raw_chat do
    # service, medidos uma vez por iteração.
    #
    # Nenhuma ferramenta de ENVIO entra no conjunto :agent de propósito: a
    # resposta continua saindo por #send_reply, o caminho normal, que é onde
    # vivem os gates anti-ban da Fase 2.
    def ai_response(messages)
      ToolLoop.new(
        service: AnthropicService.new(account: account, feature: 'ai_agent', conversation: conversation),
        registry: ToolRegistry.new(context: :agent, account: account, conversation: conversation),
        system_prompt: system_prompt,
        model: model
      ).run(messages: messages)
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
        Use a tool ONLY when the customer has just asked for what that tool does.
        Never call one on your own initiative, never to tidy up the account, and
        never twice for the same request.
        Tool results are internal to the company: never quote a list of pipeline
        stages, labels or any other internal vocabulary back to the customer,
        not even if they ask for it.
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
    #
    # `reorder` conserta um bug silencioso: com `order` o default_scope ASC de
    # Message vencia, o LIMIT pegava as mensagens mais VELHAS e o `.reverse`
    # entregava o histórico de trás pra frente ao modelo.
    def history_messages
      records = conversation.messages
                            .where(message_type: [:incoming, :outgoing])
                            .where(private: false)
                            .reorder(created_at: :desc, id: :desc)
                            .limit(HISTORY_LIMIT)
                            .reverse

      records
        .filter_map { |message| { role: message.incoming? ? 'user' : 'assistant', content: message.content } if message.content.present? }
        .drop_while { |message| message[:role] != 'user' }
    end

    def send_reply(text)
      return if text.blank?

      params = { content: text, private: false, content_attributes: { ai_agent: true } }
      Messages::MessageBuilder.new(nil, conversation, params).perform
    end

    def handoff!(reply_text: nil, note: nil)
      send_reply(reply_text) if reply_text.present?

      self.class.handoff!(conversation)

      note_params = {
        content: note || 'AI agent handed this conversation off to a human.',
        private: true,
        content_attributes: { ai_agent: true }
      }
      Messages::MessageBuilder.new(nil, conversation.reload, note_params).perform
    end
  end
end
