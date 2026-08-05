require 'rails_helper'

# Primeira suíte de Chatbots::Nodes::* do repo — sem molde de node spec pra
# copiar, o desenho segue o par gêmeo do loop agêntico (Ai::AgentReplyService)
# e o próprio Ai::ToolLoop. O Ai::ToolLoop é sempre um duplo: nenhum exemplo
# aqui chama rede.
RSpec.describe Chatbots::Nodes::AiNode do
  subject(:execute) { described_class.new(session, node).execute }

  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, name: 'Fulano') }
  let(:conversation) { create(:conversation, account: account, contact: contact) }
  let(:node_data) { { 'prompt' => 'Você é um assistente educado.' } }

  # start -> ai -> {out, handoff}: o mínimo que passa no Chatbots::FlowValidator
  # (um start, ids únicos, arestas válidas, sem ciclo quente) e dá aos dois
  # handles do nó IA um destino de verdade para o chatbot.next_node_id resolver.
  let(:flow) do
    {
      'nodes' => [
        { 'id' => 'start1', 'type' => 'start', 'data' => {} },
        { 'id' => 'ai1', 'type' => 'ai', 'data' => node_data },
        { 'id' => 'out1', 'type' => 'end', 'data' => {} },
        { 'id' => 'handoff1', 'type' => 'end', 'data' => {} }
      ],
      'edges' => [
        { 'id' => 'e1', 'source' => 'start1', 'target' => 'ai1' },
        { 'id' => 'e2', 'source' => 'ai1', 'target' => 'out1', 'sourceHandle' => 'out' },
        { 'id' => 'e3', 'source' => 'ai1', 'target' => 'handoff1', 'sourceHandle' => 'handoff' }
      ]
    }
  end

  let(:chatbot) { create(:chatbot, account: account, flow: flow) }
  let(:session) { create(:chatbot_session, account: account, chatbot: chatbot, conversation: conversation) }
  let(:node) { flow['nodes'].find { |item| item['id'] == 'ai1' } }
  let(:tool_loop) { instance_double(Ai::ToolLoop, executed: []) }

  def stub_loop(text, executed: [])
    allow(Ai::ToolLoop).to receive(:new).and_return(tool_loop)
    allow(tool_loop).to receive_messages(run: text, executed: executed)
  end

  def incoming(content, created_at:)
    create(:message, conversation: conversation, account: account, inbox: conversation.inbox,
                     message_type: :incoming, private: false, content: content, created_at: created_at)
  end

  it 'texto normal: envia a mensagem e segue pelo handle out' do
    stub_loop('Posso ajudar com isso.')

    expect { execute }.to change { conversation.messages.outgoing.count }.by(1)
    expect(execute).to eq([:continue, 'out1'])
    expect(conversation.messages.outgoing.last.content).to eq('Posso ajudar com isso.')
  end

  it 'texto com HANDOFF_MARKER: envia sem o marcador e sai pelo handle handoff' do
    marker = Ai::AgentReplyService::HANDOFF_MARKER
    stub_loop("Vou te transferir. #{marker}")

    expect(execute).to eq([:continue, 'handoff1'])
    reply = conversation.messages.outgoing.last
    expect(reply.content).to eq('Vou te transferir.')
    expect(reply.content).not_to include(marker)
  end

  it 'tool transferir_para_humano executada: sai pelo handle handoff mesmo sem marcador' do
    stub_loop('Já chamei alguém, um instante.',
              executed: [{ name: Ai::Tools::TransferirParaHumano.tool_name, input: {}, result: 'ok' }])

    expect(execute).to eq([:continue, 'handoff1'])
    expect(conversation.messages.outgoing.last.content).to eq('Já chamei alguém, um instante.')
  end

  it 'Ai::QuotaExceededError levantada pelo loop: sai pelo handle handoff sem estourar' do
    allow(Ai::ToolLoop).to receive(:new).and_return(tool_loop)
    allow(tool_loop).to receive(:run).and_raise(Ai::QuotaExceededError)

    expect { execute }.not_to raise_error
    expect(execute).to eq([:continue, 'handoff1'])
    expect(conversation.messages.outgoing.count).to eq(0)
  end

  # PARAR (Fase 2) é SEM AUTOMAÇÃO: o loop roda tools de ESCRITA antes de
  # responder, e o gate de opt-out da camada de envio só barra a MENSAGEM —
  # o que já teria sido gravado no cadastro/etiqueta/kanban ficaria gravado.
  # Fix round 1 (review F3b-T1): mesmo argumento do
  # Ai::AgentReplyService.enabled_for?, aplicado aqui porque o caminho do
  # chatbot não herda aquele gate.
  describe 'contato fora da automação' do
    it 'contato deu PARAR (automation_opted_out): sai pelo handle handoff sem chamar o modelo' do
      contact.update!(automation_opted_out: true)
      allow(Ai::ToolLoop).to receive(:new)

      expect(execute).to eq([:continue, 'handoff1'])
      expect(Ai::ToolLoop).not_to have_received(:new)
      expect(conversation.messages.count).to eq(0)
    end

    it 'contato bloqueado: sai pelo handle handoff sem chamar o modelo' do
      contact.update!(blocked: true)
      allow(Ai::ToolLoop).to receive(:new)

      expect(execute).to eq([:continue, 'handoff1'])
      expect(Ai::ToolLoop).not_to have_received(:new)
      expect(conversation.messages.count).to eq(0)
    end
  end

  describe 'data["send_reply"] é false' do
    let(:node_data) { { 'prompt' => 'p', 'send_reply' => false } }

    it 'não cria mensagem nenhuma, mas mantém o retorno normal' do
      stub_loop('Resposta que não deveria ser enviada.')

      expect { execute }.not_to change(conversation.messages, :count)
      expect(execute).to eq([:continue, 'out1'])
    end
  end

  describe 'data["save_as"] está presente' do
    let(:node_data) { { 'prompt' => 'p', 'save_as' => 'resposta_ia' } }

    it 'grava o texto do loop em session.variables' do
      stub_loop('42')

      execute

      expect(session.variables['resposta_ia']).to eq('42')
    end
  end

  it 'texto vazio do loop: sai pelo handle handoff, sem enviar nada' do
    stub_loop('')

    expect(execute).to eq([:continue, 'handoff1'])
    expect(conversation.messages.outgoing.count).to eq(0)
  end

  it 'texto nil do loop: sai pelo handle handoff, sem enviar nada' do
    stub_loop(nil)

    expect(execute).to eq([:continue, 'handoff1'])
    expect(conversation.messages.outgoing.count).to eq(0)
  end

  describe 'data["prompt"] usa variável interpolável' do
    let(:node_data) { { 'prompt' => 'Você atende {{contact.name}}.' } }

    it 'constrói o ToolLoop com registry :agent escopado na conversa e o prompt já interpolado' do
      captured = {}
      allow(Ai::ToolLoop).to receive(:new) do |**kwargs|
        captured.merge!(kwargs)
        tool_loop
      end
      allow(tool_loop).to receive_messages(run: 'ok', executed: [])

      execute

      expect(captured[:system_prompt]).to end_with('Você atende Fulano.')
      expect(captured[:system_prompt]).to include('internal to the company')
      expect(captured[:registry]).to be_a(Ai::ToolRegistry)
      expect(captured[:registry].send(:context)).to eq(:agent)
      expect(captured[:registry].send(:conversation)).to eq(conversation)
      # Decisão 3b.1: sem model:/max_tokens: na construção — os defaults do
      # raw_chat continuam valendo, comportamento inalterado.
      expect(captured).not_to have_key(:model)
      expect(captured).not_to have_key(:max_tokens)
    end
  end

  # Regressão: Message tem default_scope de created_at ASC e um `order`
  # posterior só SOMA no fim do ORDER BY — o `.reorder` é o que garante que a
  # incoming pública MAIS RECENTE (não a mais antiga) chegue ao modelo. Bug
  # real de produção na Fase 3a; este exemplo discrimina `order` de `reorder`.
  it 'usa a mensagem incoming pública mais recente como user_content (regressão do reorder)' do
    incoming('primeira mensagem', created_at: 2.minutes.ago)
    incoming('mensagem mais recente', created_at: Time.current)

    received_messages = nil
    allow(Ai::ToolLoop).to receive(:new).and_return(tool_loop)
    allow(tool_loop).to receive(:run) do |messages:|
      received_messages = messages
      'ok'
    end
    allow(tool_loop).to receive(:executed).and_return([])

    execute

    expect(received_messages).to eq([{ role: 'user', content: 'mensagem mais recente' }])
  end
end
