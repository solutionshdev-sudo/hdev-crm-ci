require 'rails_helper'

RSpec.describe Ai::AgentReplyService do
  let(:agency) { create(:agency, brand_name: 'Marca X') }
  let(:account) { create(:account, agency: agency, custom_attributes: { 'ai_agent_enabled' => true }) }
  let(:conversation) { create(:conversation, account: account) }
  let(:service) { described_class.new(conversation: conversation) }
  let(:ai_client) { instance_double(Ai::AnthropicService) }

  # O agente roda o Ai::ToolLoop desde a Fase 3a, não o #chat: o duplo do
  # service implementa os quatro seams do loop. Truque pra manter o fake curto:
  # o #raw_chat já devolve o próprio Turn e o #parse_turn é a identidade.
  def stub_ai_turns(*turns)
    allow(ai_client).to receive(:raw_chat).and_return(*turns)
    allow(ai_client).to receive(:parse_turn) { |response| response }
    allow(ai_client).to receive(:assistant_turn).and_return({ role: 'assistant', content: 'tool_use' })
    allow(ai_client).to receive(:tool_result_turn) { |results| [{ role: 'user', content: results.map(&:content).join("\n") }] }
  end

  def text_turn(text)
    Ai::ToolLoop::Turn.new(text: text, tool_calls: [])
  end

  def tool_turn(name, input = {})
    Ai::ToolLoop::Turn.new(text: '', tool_calls: [Ai::ToolLoop::Call.new(id: 'toolu_1', name: name, input: input)])
  end

  def incoming(content, created_at: 1.minute.from_now)
    create(:message, conversation: conversation, account: account, inbox: conversation.inbox,
                     message_type: :incoming, content: content, created_at: created_at)
  end

  # Hash que recebe os kwargs da chamada ao modelo, pra inspecionar o que o
  # ToolLoop montou (histórico, system prompt, ferramentas).
  def capture_raw_chat
    captured = {}
    stub_ai_turns(text_turn('ok'))
    allow(ai_client).to receive(:raw_chat) do |**kwargs|
      captured.merge!(kwargs)
      text_turn('ok')
    end
    captured
  end

  before do
    create(:message, conversation: conversation, account: account, inbox: conversation.inbox,
                     message_type: :incoming, content: 'Oi, preciso de ajuda')
    allow(Ai::AnthropicService).to receive(:new).and_return(ai_client)
  end

  describe '.enabled_for?' do
    it 'is true for enabled accounts with unassigned conversations' do
      expect(described_class.enabled_for?(conversation)).to be(true)
    end

    it 'is false when the account has not enabled the agent' do
      account.update!(custom_attributes: {})
      expect(described_class.enabled_for?(conversation)).to be(false)
    end

    it 'is false when the conversation has an assignee' do
      conversation.update!(assignee: create(:user, account: account, role: :agent))
      expect(described_class.enabled_for?(conversation)).to be(false)
    end

    it 'is false after a handoff' do
      conversation.update!(custom_attributes: { 'ai_agent_handoff' => true })
      expect(described_class.enabled_for?(conversation)).to be(false)
    end

    it 'is false when the contact opted out of automation' do
      conversation.contact.update!(automation_opted_out: true)
      expect(described_class.enabled_for?(conversation)).to be(false)
    end

    it 'is false when the contact is blocked' do
      conversation.contact.update!(blocked: true)
      expect(described_class.enabled_for?(conversation)).to be(false)
    end

    it 'respects the inbox allowlist' do
      account.update!(custom_attributes: { 'ai_agent_enabled' => true, 'ai_agent_inbox_ids' => [conversation.inbox_id + 1] })
      expect(described_class.enabled_for?(conversation)).to be(false)

      account.update!(custom_attributes: { 'ai_agent_enabled' => true, 'ai_agent_inbox_ids' => [conversation.inbox_id] })
      expect(described_class.enabled_for?(conversation)).to be(true)
    end
  end

  describe '.handoff!' do
    before { allow(Rails.configuration.dispatcher).to receive(:dispatch) }

    it 'marca a flag que cala o bot e reabre a conversa pelo bot_handoff!' do
      conversation.update!(status: :pending)

      described_class.handoff!(conversation)

      expect(conversation.reload.custom_attributes['ai_agent_handoff']).to be(true)
      expect(conversation.status).to eq('open')
      expect(described_class.enabled_for?(conversation)).to be(false)
    end

    it 'é idempotente: conversa já entregue não dispara o evento de novo' do
      described_class.handoff!(conversation)

      expect(described_class.handoff!(conversation)).to be(false)
      expect(Rails.configuration.dispatcher).to have_received(:dispatch)
        .with(Events::Types::CONVERSATION_BOT_HANDOFF, anything, hash_including(conversation: conversation)).once
    end
  end

  describe '#perform' do
    it 'sends the AI reply as an outgoing message' do
      stub_ai_turns(text_turn('Olá! Posso ajudar.'))

      expect { service.perform }.to change { conversation.messages.outgoing.count }.by(1)
      reply = conversation.messages.outgoing.last
      expect(reply.content).to eq('Olá! Posso ajudar.')
      expect(reply.content_attributes['ai_agent']).to be(true)
    end

    it 'sends the agency brand and a user-first history to the AI' do
      captured = capture_raw_chat

      service.perform

      expect(captured[:messages].first[:role]).to eq('user')
      expect(captured[:system]).to include('Marca X')
    end

    it 'oferece ao modelo o conjunto :agent de ferramentas' do
      captured = capture_raw_chat

      service.perform

      expect(captured[:tools]).to match_array(Ai::ToolRegistry::SETS[:agent])
    end

    # Regressão: Message tem default_scope ASC e o `order(created_at: :desc)`
    # que estava aqui era engolido — o modelo recebia a conversa de trás pra
    # frente.
    it 'manda o histórico em ordem cronológica, mais antiga primeiro' do
      incoming('e qual é o prazo?')
      captured = capture_raw_chat

      service.perform

      expect(captured[:messages].map { |message| message[:content] }).to eq(['Oi, preciso de ajuda', 'e qual é o prazo?'])
    end

    it 'hands off when the model asks for a human' do
      stub_ai_turns(text_turn('Vou te transferir para um atendente. [[HANDOFF]]'))

      service.perform

      expect(conversation.reload.custom_attributes['ai_agent_handoff']).to be(true)
      reply = conversation.messages.outgoing.last
      expect(reply.content).not_to include('[[HANDOFF]]')
      expect(conversation.messages.where(private: true).count).to eq(1)
    end

    it 'hands off silently when the token quota is exhausted' do
      stub_ai_turns(text_turn('nunca chega aqui'))
      allow(ai_client).to receive(:raw_chat).and_raise(Ai::QuotaExceededError)

      service.perform

      expect(conversation.reload.custom_attributes['ai_agent_handoff']).to be(true)
      # "silencioso" = nada público pro cliente; a nota privada de handoff
      # também é message_type outgoing (default do MessageBuilder)
      expect(conversation.messages.outgoing.where(private: false).count).to eq(0)
      expect(conversation.messages.where(private: true).count).to eq(1)
    end

    it 'does nothing when the agent is disabled' do
      account.update!(custom_attributes: {})
      stub_ai_turns(text_turn('ok'))

      service.perform

      expect(ai_client).not_to have_received(:raw_chat)
    end
  end

  # "PARAR" da Fase 2 é sem AUTOMAÇÃO, não só sem mensagem: o agente da F3a roda
  # cinco ferramentas de ESCRITA antes de responder, e o gate de opt-out da
  # camada de envio só barra o envio — o que já teria sido gravado no cadastro,
  # nas etiquetas e no kanban ficaria gravado.
  describe '#perform, contato fora da automação' do
    before do
      create(:label, account: account, title: 'urgente')
      # o modelo (falso) TENTA escrever: se o turno rodar, a etiqueta aparece
      stub_ai_turns(tool_turn('etiquetar_conversa', { 'etiquetas' => ['urgente'] }), text_turn('pronto'))
    end

    it 'não roda nada quando o contato deu PARAR: sem modelo, sem ferramenta, sem quota' do
      conversation.contact.update!(automation_opted_out: true)

      service.perform

      expect(Ai::AnthropicService).not_to have_received(:new)
      expect(ai_client).not_to have_received(:raw_chat)
      expect(conversation.reload.label_list).to be_blank
      expect(conversation.messages.outgoing.count).to eq(0)
    end

    it 'não roda nada quando o contato está bloqueado' do
      conversation.contact.update!(blocked: true)

      service.perform

      expect(Ai::AnthropicService).not_to have_received(:new)
      expect(ai_client).not_to have_received(:raw_chat)
      expect(conversation.reload.label_list).to be_blank
      expect(conversation.messages.outgoing.count).to eq(0)
    end
  end

  # Handoff barato: pedido explícito de humano é detectado por regex ANTES de
  # chamar o modelo. Conservador de propósito — falso positivo cala o bot à toa.
  describe '#perform, pedido explícito de atendente humano' do
    before do
      allow(Rails.configuration.dispatcher).to receive(:dispatch)
      stub_ai_turns(text_turn('a IA não deveria ter sido chamada'))
    end

    [
      'Quero falar com um atendente',
      'pode me transferir para um humano?',
      'quero atendente',
      'me passa pra uma pessoa por favor',
      'preciso falar com alguém',
      # verbo de ação abrindo a mensagem, sem verbo de desejo nenhum
      'falar com atendente',
      # verbo de desejo no meio da frase, sem pontuação antes
      'bom dia quero falar com um atendente',
      # "ser" só é ponte quando colado em atendido/atendida — o par do negativo
      # "quero ser pessoa jurídica" logo abaixo
      'quero ser atendido por um humano'
    ].each do |frase|
      it "transfere sem chamar a IA: #{frase.inspect}" do
        incoming(frase)

        service.perform

        expect(conversation.reload.custom_attributes['ai_agent_handoff']).to be(true)
        expect(ai_client).not_to have_received(:raw_chat)
        # o caminho barato é silencioso: o cliente não recebe resposta do bot
        expect(conversation.messages.outgoing.where(private: false).count).to eq(0)
      end
    end

    [
      'meu atendente favorito resolveu',
      'a pessoa que me atendeu foi ótima',
      # elogio de pós-atendimento: verbo de ação sem abrir oração
      'adorei falar com o atendente de vocês',
      'gostei de falar com a pessoa que me atendeu',
      'não quero falar com atendente',
      'quero saber o status do meu pedido',
      # "pessoa" é substantivo comum: frases de cadastro/comercial que um CRM
      # vendido pra agência recebe todo dia não podem calar o bot pra sempre
      'quero ser pessoa jurídica',
      'preciso ser pessoa jurídica pra emitir nota',
      'quero uma pessoa de contato no comercial',
      'gostaria de uma pessoa jurídica no cadastro',
      'preciso de uma pessoa para assinar o contrato'
    ].each do |frase|
      it "menção solta não transfere, segue pra IA: #{frase.inspect}" do
        incoming(frase)

        service.perform

        expect(conversation.reload.custom_attributes['ai_agent_handoff']).to be_falsey
        expect(ai_client).to have_received(:raw_chat)
      end
    end

    it 'não custa nada: nem AnthropicService instanciado, nem AiUsageEvent gravado' do
      incoming('quero falar com um atendente')

      expect { service.perform }.not_to change(AiUsageEvent, :count)
      expect(Ai::AnthropicService).not_to have_received(:new)
    end

    it 'emite CONVERSATION_BOT_HANDOFF uma única vez e cala o bot nos turnos seguintes' do
      incoming('quero falar com um atendente')

      service.perform

      expect(Rails.configuration.dispatcher).to have_received(:dispatch)
        .with(Events::Types::CONVERSATION_BOT_HANDOFF, anything, hash_including(conversation: conversation)).once
      expect(described_class.enabled_for?(conversation.reload)).to be(false)
    end

    it 'olha só a última mensagem recebida, não o histórico inteiro' do
      incoming('quero falar com um atendente')
      incoming('deixa pra lá, resolvi sozinho', created_at: 2.minutes.from_now)

      service.perform

      expect(conversation.reload.custom_attributes['ai_agent_handoff']).to be_falsey
      expect(ai_client).to have_received(:raw_chat)
    end
  end

  # Os dois outros caminhos de handoff (marcador e quota) passam pelo mesmo
  # ponto de entrada e precisam reagir igual no barramento.
  describe '#perform, evento de handoff nos caminhos que passam pela IA' do
    before { allow(Rails.configuration.dispatcher).to receive(:dispatch) }

    it 'emite CONVERSATION_BOT_HANDOFF quando o modelo devolve o marcador' do
      stub_ai_turns(text_turn("Já chamei alguém. #{described_class::HANDOFF_MARKER}"))

      service.perform

      expect(Rails.configuration.dispatcher).to have_received(:dispatch)
        .with(Events::Types::CONVERSATION_BOT_HANDOFF, anything, hash_including(conversation: conversation)).once
      expect(described_class.enabled_for?(conversation.reload)).to be(false)
    end

    it 'emite CONVERSATION_BOT_HANDOFF quando a quota estoura' do
      stub_ai_turns(text_turn('nunca chega aqui'))
      allow(ai_client).to receive(:raw_chat).and_raise(Ai::QuotaExceededError)

      service.perform

      expect(Rails.configuration.dispatcher).to have_received(:dispatch)
        .with(Events::Types::CONVERSATION_BOT_HANDOFF, anything, hash_including(conversation: conversation)).once
      expect(described_class.enabled_for?(conversation.reload)).to be(false)
    end
  end

  # Ponta a ponta: modelo (falso) chama ferramenta do conjunto :agent, a
  # ferramenta roda de verdade e o efeito aparece no banco.
  describe '#perform, loop de ferramentas' do
    before { allow(Rails.configuration.dispatcher).to receive(:dispatch) }

    it 'aplica a etiqueta pedida pelo modelo e responde com o texto final' do
      create(:label, account: account, title: 'urgente')
      stub_ai_turns(tool_turn('etiquetar_conversa', { 'etiquetas' => ['urgente'] }), text_turn('Pronto, anotei aqui.'))

      service.perform

      expect(conversation.reload.label_list).to include('urgente')
      expect(conversation.messages.outgoing.where(private: false).last.content).to eq('Pronto, anotei aqui.')
    end

    it 'transferir_para_humano cala o bot e emite um único CONVERSATION_BOT_HANDOFF' do
      stub_ai_turns(tool_turn('transferir_para_humano'), text_turn('Já chamei alguém, um instante.'))

      service.perform

      expect(described_class.enabled_for?(conversation.reload)).to be(false)
      expect(Rails.configuration.dispatcher).to have_received(:dispatch)
        .with(Events::Types::CONVERSATION_BOT_HANDOFF, anything, hash_including(conversation: conversation)).once
    end

    it 'não duplica o evento quando a ferramenta e o marcador pedem handoff no mesmo turno' do
      stub_ai_turns(tool_turn('transferir_para_humano'), text_turn("Já chamei alguém. #{described_class::HANDOFF_MARKER}"))

      service.perform

      expect(Rails.configuration.dispatcher).to have_received(:dispatch)
        .with(Events::Types::CONVERSATION_BOT_HANDOFF, anything, hash_including(conversation: conversation)).once
    end
  end
end
