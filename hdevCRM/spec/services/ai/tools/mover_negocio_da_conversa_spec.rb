require 'rails_helper'

RSpec.describe Ai::Tools::MoverNegocioDaConversa do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:pipeline) { create(:deal_pipeline, account: account) }
  let!(:novo) { create(:deal_stage, account: account, deal_pipeline: pipeline, name: 'Novo Lead', position: 1) }
  let!(:proposta) { create(:deal_stage, account: account, deal_pipeline: pipeline, name: 'Proposta Enviada', position: 2) }
  let!(:perdido) { create(:deal_stage, :lost, account: account, deal_pipeline: pipeline, name: 'Perdido', position: 3) }
  let!(:deal) do
    create(:deal, account: account, deal_pipeline: pipeline, deal_stage: novo,
                  contact: conversation.contact, conversation: conversation)
  end
  let(:tool) { described_class.new(account: account, user: nil, conversation: conversation) }

  it 'move o negócio aberto da conversa para a etapa informada' do
    resultado = tool.call('etapa' => 'Proposta Enviada')

    expect(deal.reload.deal_stage).to eq(proposta)
    expect(resultado).to include('Proposta Enviada')
  end

  it 'resolve o nome da etapa sem diferenciar maiúsculas de minúsculas' do
    tool.call('etapa' => 'proposta enviada')

    expect(deal.reload.deal_stage).to eq(proposta)
  end

  it 'lista as etapas disponíveis quando o nome da etapa não existe no funil' do
    expect { tool.call('etapa' => 'Etapa Fantasma') }
      .to raise_error(Ai::ToolError, /Novo Lead, Proposta Enviada, Perdido/)

    expect(deal.reload.deal_stage).to eq(novo)
  end

  it 'grava o motivo padrão ao mover para etapa perdida, em vez de estourar a validação do Deal' do
    tool.call('etapa' => 'Perdido')

    deal.reload
    expect(deal.deal_stage).to eq(perdido)
    expect(deal.lost_reason).to eq(I18n.t('automation.default_lost_reason'))
    expect(deal).to be_lost
  end

  it 'não sobrescreve o motivo de perda que o negócio já tinha' do
    deal.update!(lost_reason: 'fechou com concorrente')

    tool.call('etapa' => 'Perdido')

    expect(deal.reload.lost_reason).to eq('fechou com concorrente')
  end

  it 'devolve resposta explicativa quando a conversa não tem negócio aberto' do
    outra_conversa = create(:conversation, account: account)
    ferramenta = described_class.new(account: account, user: nil, conversation: outra_conversa)

    expect(ferramenta.call('etapa' => 'Proposta Enviada')).to include('não tem negócio aberto')
    expect(deal.reload.deal_stage).to eq(novo)
  end

  it 'levanta erro claro quando não há conversa no contexto' do
    ferramenta = described_class.new(account: account, user: nil)

    expect { ferramenta.call('etapa' => 'Proposta Enviada') }.to raise_error(Ai::ToolError, /conversa/)
  end

  context 'with forged ids pointing at another account' do
    let(:outra_conta) { create(:account) }
    let(:outra_conversa) { create(:conversation, account: outra_conta) }
    let(:outro_pipeline) { create(:deal_pipeline, account: outra_conta) }
    let!(:outra_etapa) { create(:deal_stage, account: outra_conta, deal_pipeline: outro_pipeline, name: 'Etapa Secreta') }
    let!(:outro_deal) do
      create(:deal, account: outra_conta, deal_pipeline: outro_pipeline, deal_stage: outra_etapa,
                    contact: outra_conversa.contact, conversation: outra_conversa)
    end

    it 'ignora os ids forjados e move apenas o negócio da conversa injetada' do
      input = {
        'etapa' => 'Proposta Enviada',
        'deal_id' => outro_deal.id,
        'conversation_id' => outra_conversa.id,
        'account_id' => outra_conta.id
      }

      tool.call(input)

      expect(deal.reload.deal_stage).to eq(proposta)
      expect(outro_deal.reload.deal_stage).to eq(outra_etapa)
    end

    it 'não alcança pelo nome uma etapa que só existe no funil da outra conta' do
      expect { tool.call('etapa' => 'Etapa Secreta') }.to raise_error(Ai::ToolError, /não existe neste funil/)

      expect(deal.reload.deal_stage).to eq(novo)
      expect(outro_deal.reload.deal_stage).to eq(outra_etapa)
    end
  end
end
