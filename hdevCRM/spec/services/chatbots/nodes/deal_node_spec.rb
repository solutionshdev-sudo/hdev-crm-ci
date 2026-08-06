require 'rails_helper'

# Dívida da F4 (ledger: "DealNode sem spec — criar na F3b"). Segue o molde do
# ai_node_spec: mesmo shape mínimo de flow (start -> deal -> end) que passa no
# Chatbots::FlowValidator, sem chamar rede (o nó não toca IA).
RSpec.describe Chatbots::Nodes::DealNode do
  subject(:execute) { described_class.new(session, node).execute }

  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, name: 'Fulano') }
  let(:conversation) { create(:conversation, account: account, contact: contact) }
  let(:node_data) { {} }

  let(:flow) do
    {
      'nodes' => [
        { 'id' => 'start1', 'type' => 'start', 'data' => {} },
        { 'id' => 'deal1', 'type' => 'deal', 'data' => node_data },
        { 'id' => 'end1', 'type' => 'end', 'data' => {} }
      ],
      'edges' => [
        { 'id' => 'e1', 'source' => 'start1', 'target' => 'deal1' },
        { 'id' => 'e2', 'source' => 'deal1', 'target' => 'end1' }
      ]
    }
  end

  let(:chatbot) { create(:chatbot, account: account, flow: flow) }
  let(:session) { create(:chatbot_session, account: account, chatbot: chatbot, conversation: conversation) }
  let(:node) { flow['nodes'].find { |item| item['id'] == 'deal1' } }

  it 'retorno normal: cria o deal e segue pelo next_id' do
    expect { execute }.to change(account.deals, :count).by(1)
    expect(execute).to eq([:continue, 'end1'])
  end

  describe 'data["pipeline_id"] e data["stage_id"] presentes' do
    let(:pipeline) { create(:deal_pipeline, account: account) }
    let(:stage) { create(:deal_stage, account: account, deal_pipeline: pipeline, position: 1) }
    let(:node_data) { { 'pipeline_id' => pipeline.id, 'stage_id' => stage.id } }

    it 'cria o deal no pipeline/stage indicados' do
      execute

      deal = account.deals.last
      expect(deal.deal_pipeline).to eq(pipeline)
      expect(deal.deal_stage).to eq(stage)
    end
  end

  describe 'data["pipeline_id"] ausente' do
    let(:node_data) { {} }

    it 'usa DealPipeline.ensure_default! (funil default da conta)' do
      execute

      deal = account.deals.last
      expect(deal.deal_pipeline).to eq(DealPipeline.ensure_default!(account))
    end
  end

  describe 'data["pipeline_id"] aponta pra um pipeline inexistente' do
    let(:node_data) { { 'pipeline_id' => 0 } }

    it 'usa DealPipeline.ensure_default! (funil default da conta)' do
      execute

      deal = account.deals.last
      expect(deal.deal_pipeline).to eq(DealPipeline.ensure_default!(account))
    end
  end

  describe 'data["stage_id"] ausente' do
    let(:pipeline) { create(:deal_pipeline, account: account) }
    let(:node_data) { { 'pipeline_id' => pipeline.id } }

    it 'usa a primeira etapa por position' do
      third = create(:deal_stage, account: account, deal_pipeline: pipeline, position: 3)
      first = create(:deal_stage, account: account, deal_pipeline: pipeline, position: 1)
      create(:deal_stage, account: account, deal_pipeline: pipeline, position: 2)

      execute

      deal = account.deals.last
      expect(deal.deal_stage).to eq(first)
      expect(deal.deal_stage).not_to eq(third)
    end
  end

  describe 'etapa é lost' do
    let(:pipeline) { create(:deal_pipeline, account: account) }
    let(:stage) { create(:deal_stage, :lost, account: account, deal_pipeline: pipeline, position: 1) }
    let(:node_data) { { 'pipeline_id' => pipeline.id, 'stage_id' => stage.id } }

    it 'preenche lost_reason com o motivo default de automação' do
      execute

      deal = account.deals.last
      expect(deal.lost_reason).to eq(I18n.t('automation.default_lost_reason'))
    end
  end

  describe 'data["title_template"]' do
    describe 'com {{contact.name}}' do
      let(:node_data) { { 'title_template' => 'Negócio com {{contact.name}}' } }

      it 'interpola o template' do
        execute

        expect(account.deals.last.title).to eq('Negócio com Fulano')
      end
    end

    describe 'ausente, com contato nomeado' do
      let(:node_data) { {} }

      it 'usa o nome do contato' do
        execute

        expect(account.deals.last.title).to eq('Fulano')
      end
    end

    describe 'ausente, sem contato com nome' do
      let(:contact) { create(:contact, account: account, name: '') }
      let(:node_data) { {} }

      it "usa 'Novo negócio'" do
        execute

        expect(account.deals.last.title).to eq('Novo negócio')
      end
    end
  end

  describe 'data["value_template"] numérico' do
    let(:node_data) { { 'value_template' => '1500.50' } }

    it 'interpolado vira value float' do
      execute

      expect(account.deals.last.value).to eq(1500.50)
    end
  end

  describe 'RecordInvalid ao criar o deal' do
    # value < 0 é a validação real de Deal (numericality greater_than_or_equal_to: 0)
    # que dá pra forçar por fora do controle do node, sem mockar nada.
    let(:node_data) { { 'value_template' => '-50' } }

    it 'não deixa a exceção vazar: loga :failed e segue pelo next_id normal' do
      # `execute` é um subject memoizado (let) — uma só invocação real por
      # exemplo. A invocação real acontece aqui, dentro do `expect { execute
      # }`; as leituras depois disso vão direto no banco (sem chamar
      # `execute` de novo, que só devolveria o valor já memoizado).
      # `account.deals.count` fica como igualdade simples (não
      # `change(...).by(0)`) pra não disparar RSpec/ChangeByZero.
      expect { execute }.to change(session.chatbot_session_events, :count).by(1)
      expect(account.deals.count).to eq(0)
      expect(execute).to eq([:continue, 'end1'])

      event = session.chatbot_session_events.last
      expect(event.event_type).to eq('failed')
      expect(event.node_id).to eq('deal1')
    end
  end
end
