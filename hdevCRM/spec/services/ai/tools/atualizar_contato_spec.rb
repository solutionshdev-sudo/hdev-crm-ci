require 'rails_helper'

RSpec.describe Ai::Tools::AtualizarContato do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, name: 'Contato Antigo', email: 'antigo@example.com') }
  let(:conversation) { create(:conversation, account: account, contact: contact) }
  let(:tool) { described_class.new(account: account, user: nil, conversation: conversation) }

  it 'atualiza nome e e-mail do contato da conversa' do
    resultado = tool.call('nome' => 'Maria Silva', 'email' => 'Maria@Empresa.com')

    contact.reload
    expect(contact.name).to eq('Maria Silva')
    expect(contact.email).to eq('maria@empresa.com')
    expect(resultado).to include('Maria Silva')
  end

  it 'mantém o valor atual do campo omitido' do
    tool.call('nome' => 'Maria Silva')

    contact.reload
    expect(contact.name).to eq('Maria Silva')
    expect(contact.email).to eq('antigo@example.com')
  end

  it 'trata campo em branco como omitido, para não apagar o cadastro' do
    tool.call('nome' => 'Maria Silva', 'email' => '   ')

    contact.reload
    expect(contact.name).to eq('Maria Silva')
    expect(contact.email).to eq('antigo@example.com')
  end

  it 'devolve a mensagem de validação como Ai::ToolError quando o e-mail é inválido' do
    expect { tool.call('email' => 'maria arroba empresa') }.to raise_error(Ai::ToolError, /Invalid email/)

    expect(contact.reload.email).to eq('antigo@example.com')
  end

  it 'devolve erro quando o e-mail já pertence a outro contato da conta' do
    create(:contact, account: account, email: 'ocupado@example.com')

    expect { tool.call('email' => 'ocupado@example.com') }.to raise_error(Ai::ToolError, /already been taken/)

    expect(contact.reload.email).to eq('antigo@example.com')
  end

  it 'avisa o modelo quando nenhum campo foi informado' do
    expect(tool.call({})).to include('Nenhum dado informado')
  end

  it 'devolve resposta explicativa quando a conversa não tem contato' do
    allow(conversation).to receive(:contact).and_return(nil)

    expect(tool.call('nome' => 'Maria Silva')).to include('não tem contato associado')
  end

  it 'levanta erro claro quando não há conversa no contexto' do
    ferramenta = described_class.new(account: account, user: nil)

    expect { ferramenta.call('nome' => 'Maria Silva') }.to raise_error(Ai::ToolError, /conversa/)
  end

  context 'with forged ids pointing at another account' do
    let(:outra_conta) { create(:account) }
    let!(:outro_contato) { create(:contact, account: outra_conta, name: 'Alvo', email: 'alvo@example.com') }

    it 'ignora os ids forjados e altera apenas o contato da conversa injetada' do
      input = {
        'nome' => 'Maria Silva',
        'contact_id' => outro_contato.id,
        'conversation_id' => 999_999,
        'account_id' => outra_conta.id
      }

      tool.call(input)

      expect(contact.reload.name).to eq('Maria Silva')
      expect(outro_contato.reload.name).to eq('Alvo')
      expect(outro_contato.email).to eq('alvo@example.com')
    end
  end
end
