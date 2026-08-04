require 'rails_helper'

RSpec.describe Ai::Tools::EtiquetarConversa do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:tool) { described_class.new(account: account, user: nil, conversation: conversation) }

  context 'when the account has labels registered' do
    before do
      create(:label, account: account, title: 'urgente')
      create(:label, account: account, title: 'orçamento-enviado')
    end

    it 'aplica as etiquetas conhecidas na conversa da vez' do
      resultado = tool.call('etiquetas' => %w[urgente orçamento-enviado])

      expect(conversation.reload.label_list).to contain_exactly('urgente', 'orçamento-enviado')
      expect(resultado).to include('urgente').and include('orçamento-enviado')
    end

    it 'resolve o nome sem diferenciar maiúsculas de minúsculas e aplica o title canônico da conta' do
      tool.call('etiquetas' => ['URGENTE'])

      expect(conversation.reload.label_list).to contain_exactly('urgente')
    end

    it 'chamada repetida não duplica a mesma etiqueta' do
      tool.call('etiquetas' => ['urgente'])
      tool.call('etiquetas' => ['urgente'])

      expect(conversation.reload.label_list.count).to eq(1)
    end

    it 'soma com etiquetas que a conversa já tinha, em vez de substituir' do
      conversation.update!(label_list: ['urgente'])

      tool.call('etiquetas' => ['orçamento-enviado'])

      expect(conversation.reload.label_list).to contain_exactly('urgente', 'orçamento-enviado')
    end

    it 'levanta Ai::ToolError com a lista de etiquetas disponíveis quando o nome não existe na conta' do
      expect { tool.call('etiquetas' => ['inexistente']) }.to raise_error(Ai::ToolError) do |erro|
        expect(erro.message).to include("'inexistente'").and include('não existe nesta conta')
        expect(erro.message).to include('urgente').and include('orçamento-enviado')
      end

      expect(conversation.reload.label_list).to be_blank
    end

    it 'não aplica nada quando a lista mistura etiqueta conhecida e desconhecida (tudo-ou-nada)' do
      expect { tool.call('etiquetas' => %w[urgente inexistente]) }.to raise_error(Ai::ToolError, /inexistente/)

      expect(conversation.reload.label_list).to be_blank
    end

    it 'devolve resposta útil quando a lista de etiquetas é vazia, sem gerar erro de servidor' do
      expect(tool.call('etiquetas' => [])).to include('não tem etiquetas')
    end

    it 'devolve resposta útil quando o campo etiquetas está ausente' do
      expect(tool.call({})).to include('não tem etiquetas')
    end
  end

  context 'when the account has no labels registered' do
    it 'devolve resposta útil em vez de erro obscuro' do
      resultado = tool.call('etiquetas' => ['urgente'])

      expect(resultado).to include('não tem etiquetas cadastradas')
      expect(conversation.reload.label_list).to be_blank
    end
  end

  it 'levanta erro claro quando não há conversa no contexto' do
    ferramenta = described_class.new(account: account, user: nil)

    expect { ferramenta.call('etiquetas' => ['urgente']) }.to raise_error(Ai::ToolError, /conversa/)
  end

  context 'with forged ids pointing at another conversation' do
    let(:outra_conta) { create(:account) }
    let!(:outra_conversa) { create(:conversation, account: outra_conta) }

    before { create(:label, account: account, title: 'urgente') }

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

    context 'when the label only exists on the other account' do
      before { create(:label, account: outra_conta, title: 'secreta-da-outra-conta') }

      it 'rejeita a etiqueta como desconhecida, em vez de vazar o vocabulário de outra conta' do
        expect { tool.call('etiquetas' => ['secreta-da-outra-conta']) }
          .to raise_error(Ai::ToolError, /secreta-da-outra-conta.*não existe nesta conta/m)

        expect(conversation.reload.label_list).to be_blank
        expect(outra_conversa.reload.label_list).to be_blank
      end
    end
  end
end
