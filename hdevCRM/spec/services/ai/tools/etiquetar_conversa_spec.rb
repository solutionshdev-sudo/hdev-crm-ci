require 'rails_helper'

RSpec.describe Ai::Tools::EtiquetarConversa do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:tool) { described_class.new(account: account, user: nil, conversation: conversation) }

  it 'aplica as etiquetas informadas na conversa da vez' do
    resultado = tool.call('etiquetas' => %w[urgente orçamento-enviado])

    expect(conversation.reload.label_list).to contain_exactly('urgente', 'orçamento-enviado')
    expect(resultado).to include('urgente').and include('orçamento-enviado')
  end

  it 'cria e associa etiqueta nova sem erro' do
    expect { tool.call('etiquetas' => ['inédita-nesta-conta']) }.not_to raise_error

    expect(conversation.reload.label_list).to contain_exactly('inédita-nesta-conta')
  end

  it 'chamada repetida não duplica a mesma etiqueta' do
    tool.call('etiquetas' => ['vip'])
    tool.call('etiquetas' => ['vip'])

    expect(conversation.reload.label_list.count).to eq(1)
  end

  it 'soma com etiquetas que a conversa já tinha, em vez de substituir' do
    conversation.update!(label_list: ['ja-tinha'])

    tool.call('etiquetas' => ['nova'])

    expect(conversation.reload.label_list).to contain_exactly('ja-tinha', 'nova')
  end

  it 'devolve resposta útil quando a lista de etiquetas é vazia, sem gerar erro de servidor' do
    expect(tool.call('etiquetas' => [])).to include('não tem etiquetas')
  end

  it 'devolve resposta útil quando o campo etiquetas está ausente' do
    expect(tool.call({})).to include('não tem etiquetas')
  end

  it 'levanta erro claro quando não há conversa no contexto' do
    ferramenta = described_class.new(account: account, user: nil)

    expect { ferramenta.call('etiquetas' => ['vip']) }.to raise_error(Ai::ToolError, /conversa/)
  end

  context 'with forged ids pointing at another conversation' do
    let(:outra_conta) { create(:account) }
    let!(:outra_conversa) { create(:conversation, account: outra_conta) }

    it 'ignora os ids forjados e etiqueta apenas a conversa injetada' do
      input = {
        'etiquetas' => ['urgente'],
        'conversation_id' => outra_conversa.id,
        'account_id' => outra_conta.id
      }

      tool.call(input)

      expect(conversation.reload.label_list).to contain_exactly('urgente')
      expect(outra_conversa.reload.label_list).to be_blank
    end
  end
end
