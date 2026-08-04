require 'rails_helper'

RSpec.describe Ai::Tools::TransferirParaHumano do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account, status: :pending) }
  let(:tool) { described_class.new(account: account, user: nil, conversation: conversation) }

  before do
    allow(Rails.configuration.dispatcher).to receive(:dispatch)
  end

  it 'reabre a conversa (status open) ao transferir' do
    tool.call({})

    expect(conversation.reload.status).to eq('open')
  end

  it 'dispara o evento CONVERSATION_BOT_HANDOFF da conversa desta ferramenta' do
    tool.call({})

    expect(Rails.configuration.dispatcher).to have_received(:dispatch)
      .with(Events::Types::CONVERSATION_BOT_HANDOFF, anything, hash_including(conversation: conversation))
  end

  it 'devolve string final para o modelo se despedir' do
    resultado = tool.call({})

    expect(resultado).to be_a(String)
    expect(resultado).to include('transferida')
  end

  it 'levanta erro claro quando não há conversa no contexto' do
    ferramenta = described_class.new(account: account, user: nil)

    expect { ferramenta.call({}) }.to raise_error(Ai::ToolError, /conversa/)
  end

  context 'without any input, since the schema has no parameters' do
    it 'funciona normalmente mesmo recebendo hash vazio' do
      expect { tool.call({}) }.not_to raise_error
    end
  end

  context 'with a forged conversation_id pointing at another conversation' do
    let(:outra_conta) { create(:account) }
    let!(:outra_conversa) { create(:conversation, account: outra_conta, status: :pending) }

    it 'ignora o id forjado e transfere apenas a conversa injetada, deixando a outra intocada' do
      input = { 'conversation_id' => outra_conversa.id, 'account_id' => outra_conta.id }

      tool.call(input)

      expect(conversation.reload.status).to eq('open')
      expect(outra_conversa.reload.status).to eq('pending')
      expect(Rails.configuration.dispatcher).not_to have_received(:dispatch)
        .with(Events::Types::CONVERSATION_BOT_HANDOFF, anything, hash_including(conversation: outra_conversa))
    end
  end
end
