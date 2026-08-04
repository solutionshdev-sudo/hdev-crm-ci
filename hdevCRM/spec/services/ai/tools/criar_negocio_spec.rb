require 'rails_helper'

RSpec.describe Ai::Tools::CriarNegocio do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:pipeline) { create(:deal_pipeline, account: account) }
  let!(:primeira) { create(:deal_stage, account: account, deal_pipeline: pipeline, name: 'Novo Lead', position: 1) }
  let!(:proposta) { create(:deal_stage, account: account, deal_pipeline: pipeline, name: 'Proposta Enviada', position: 2) }
  let(:tool) { described_class.new(account: account, user: nil, conversation: conversation) }

  it 'cria o negócio ligado ao contato e à conversa, na primeira etapa do funil padrão' do
    expect { tool.call({}) }.to change(account.deals, :count).by(1)

    deal = account.deals.last
    expect(deal.conversation).to eq(conversation)
    expect(deal.contact).to eq(conversation.contact)
    expect(deal.deal_stage).to eq(primeira)
  end

  it 'cria na etapa informada pelo nome, resolvida dentro do funil padrão' do
    resultado = tool.call('etapa' => 'proposta enviada')

    expect(account.deals.last.deal_stage).to eq(proposta)
    expect(resultado).to include('Proposta Enviada')
  end

  it 'lista as etapas disponíveis quando o nome da etapa não existe' do
    expect { tool.call('etapa' => 'Etapa Fantasma') }
      .to raise_error(Ai::ToolError, /Novo Lead, Proposta Enviada/)

    expect(account.deals.count).to eq(0)
  end

  it 'é idempotente por conversa: a segunda chamada não cria outro negócio e diz isso ao modelo' do
    tool.call({})

    resultado = nil
    expect { resultado = tool.call({}) }.not_to change(Deal, :count)
    expect(resultado).to include('já tem o negócio aberto')
  end

  it 'não cria negócio quando a conversa não tem contato' do
    allow(conversation).to receive(:contact).and_return(nil)

    expect { tool.call({}) }.not_to change(Deal, :count)
    expect(tool.call({})).to include('não tem contato associado')
  end

  it 'levanta erro claro quando não há conversa no contexto' do
    ferramenta = described_class.new(account: account, user: nil)

    expect { ferramenta.call({}) }.to raise_error(Ai::ToolError, /conversa/)
  end

  # Ciclo de prompt injection: entrar em etapa perdida tira o negócio do `open`
  # (Deal#apply_stage_outcome), o guard de idempotência é `open`-scoped, e o
  # modelo repetiria criar -> mover("Perdido") -> criar dentro de um turno,
  # publicando card atrás de card no kanban da conta inteira.
  context 'when the conversation already hit the deal cap' do
    let!(:perdido) { create(:deal_stage, :lost, account: account, deal_pipeline: pipeline, name: 'Perdido', position: 3) }

    def fechar_negocios(quantos)
      quantos.times do
        create(:deal, account: account, deal_pipeline: pipeline, deal_stage: perdido, lost_reason: 'ciclo',
                      contact: conversation.contact, conversation: conversation)
      end
    end

    it 'recusa em texto quando o teto já foi atingido, contando negócio FECHADO' do
      fechar_negocios(described_class::MAX_DEALS_POR_CONVERSA)
      fechados = account.deals.where(conversation_id: conversation.id)

      resultado = nil
      expect { resultado = tool.call({}) }.not_to change(Deal, :count)

      expect(fechados.open.count).to eq(0)
      expect(resultado).to eq(described_class::LIMITE_ATINGIDO)
    end

    it 'ainda cria enquanto a conversa está abaixo do teto' do
      fechar_negocios(described_class::MAX_DEALS_POR_CONVERSA - 1)

      expect { tool.call({}) }.to change(Deal, :count).by(1)
    end
  end

  context 'with forged ids pointing at another account' do
    let(:outra_conta) { create(:account) }
    let(:outra_conversa) { create(:conversation, account: outra_conta) }

    it 'ignora os ids forjados e cria o negócio apenas na conversa injetada' do
      input = {
        'conversation_id' => outra_conversa.id,
        'contact_id' => outra_conversa.contact_id,
        'account_id' => outra_conta.id
      }

      expect { tool.call(input) }.to change(account.deals, :count).by(1)

      expect(account.deals.last.conversation).to eq(conversation)
      expect(outra_conta.deals.count).to eq(0)
      expect(account.deals.where(conversation_id: outra_conversa.id)).to be_empty
    end
  end
end
