require 'rails_helper'

RSpec.describe Ai::AgentReplyService do
  let(:agency) { create(:agency, brand_name: 'Marca X') }
  let(:account) { create(:account, agency: agency, custom_attributes: { 'ai_agent_enabled' => true }) }
  let(:conversation) { create(:conversation, account: account) }
  let(:service) { described_class.new(conversation: conversation) }
  let(:ai_client) { instance_double(Ai::AnthropicService) }

  def ai_response(text)
    double(content: [double(text: text)]) # rubocop:disable RSpec/VerifiedDoubles
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

    it 'respects the inbox allowlist' do
      account.update!(custom_attributes: { 'ai_agent_enabled' => true, 'ai_agent_inbox_ids' => [conversation.inbox_id + 1] })
      expect(described_class.enabled_for?(conversation)).to be(false)

      account.update!(custom_attributes: { 'ai_agent_enabled' => true, 'ai_agent_inbox_ids' => [conversation.inbox_id] })
      expect(described_class.enabled_for?(conversation)).to be(true)
    end
  end

  describe '#perform' do
    it 'sends the AI reply as an outgoing message' do
      allow(ai_client).to receive(:chat).and_return(ai_response('Olá! Posso ajudar.'))

      expect { service.perform }.to change { conversation.messages.outgoing.count }.by(1)
      reply = conversation.messages.outgoing.last
      expect(reply.content).to eq('Olá! Posso ajudar.')
      expect(reply.content_attributes['ai_agent']).to be(true)
    end

    it 'sends the agency brand and a user-first history to the AI' do
      captured = nil
      allow(ai_client).to receive(:chat) do |**kwargs|
        captured = kwargs
        ai_response('ok')
      end

      service.perform

      expect(captured[:messages].first[:role]).to eq('user')
      expect(captured[:system]).to include('Marca X')
    end

    it 'hands off when the model asks for a human' do
      allow(ai_client).to receive(:chat).and_return(ai_response('Vou te transferir para um atendente. [[HANDOFF]]'))

      service.perform

      expect(conversation.reload.custom_attributes['ai_agent_handoff']).to be(true)
      reply = conversation.messages.outgoing.last
      expect(reply.content).not_to include('[[HANDOFF]]')
      expect(conversation.messages.where(private: true).count).to eq(1)
    end

    it 'hands off silently when the token quota is exhausted' do
      allow(ai_client).to receive(:chat).and_raise(Ai::QuotaExceededError)

      service.perform

      expect(conversation.reload.custom_attributes['ai_agent_handoff']).to be(true)
      # "silencioso" = nada público pro cliente; a nota privada de handoff
      # também é message_type outgoing (default do MessageBuilder)
      expect(conversation.messages.outgoing.where(private: false).count).to eq(0)
      expect(conversation.messages.where(private: true).count).to eq(1)
    end

    it 'does nothing when the agent is disabled' do
      account.update!(custom_attributes: {})
      allow(ai_client).to receive(:chat)

      service.perform

      expect(ai_client).not_to have_received(:chat)
    end
  end
end
