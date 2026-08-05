require 'rails_helper'

RSpec.describe Ai::Tools::CreateChatbotFlow do
  let(:account) { create(:account) }
  let(:tool) { described_class.new(account: account, user: nil) }

  let(:valid_input) do
    {
      'name' => 'Triagem de suporte',
      'nodes' => [
        { 'id' => 'n1', 'type' => 'start', 'data' => {} },
        { 'id' => 'n2', 'type' => 'message', 'data' => { 'content' => 'Olá, {{contact.name}}!' } },
        { 'id' => 'n3', 'type' => 'end', 'data' => { 'resolve_conversation' => true } }
      ],
      'edges' => [
        { 'id' => 'e1', 'source' => 'n1', 'target' => 'n2' },
        { 'id' => 'e2', 'source' => 'n2', 'target' => 'n3' }
      ]
    }
  end

  it 'cria o chatbot como rascunho, para o usuário revisar antes de ativar' do
    expect { tool.call(valid_input) }.to change(account.chatbots, :count).by(1)

    chatbot = account.chatbots.last
    expect(chatbot).to be_draft
    expect(chatbot.name).to eq('Triagem de suporte')
    expect(chatbot.flow['nodes'].size).to eq(3)
  end

  it 'atribui posição a cada nó — o editor visual precisa e o modelo não deve fazer layout' do
    tool.call(valid_input)

    positions = account.chatbots.last.flow['nodes'].map { |node| node['position'] }
    expect(positions).to all(include('x', 'y'))
    expect(positions.map { |p| p['y'] }.uniq.size).to eq(3)
  end

  it 'preserva o sourceHandle quando informado e omite quando ausente' do
    input = valid_input.merge(
      'edges' => [
        { 'id' => 'e1', 'source' => 'n1', 'target' => 'n2' },
        { 'id' => 'e2', 'source' => 'n2', 'target' => 'n3', 'sourceHandle' => 'fallback' }
      ]
    )
    tool.call(input)

    edges = account.chatbots.last.flow['edges']
    expect(edges.first).not_to have_key('sourceHandle')
    expect(edges.second['sourceHandle']).to eq('fallback')
  end

  it 'devolve os erros do FlowValidator como Ai::ToolError para o modelo corrigir' do
    input = valid_input.merge(
      'nodes' => valid_input['nodes'] + [{ 'id' => 'n4', 'type' => 'start', 'data' => {} }]
    )

    expect { tool.call(input) }.to raise_error(Ai::ToolError, /exactly one start node/)
    expect(account.chatbots.count).to eq(0)
  end

  it 'rejeita aresta apontando para nó inexistente' do
    input = valid_input.merge(
      'edges' => valid_input['edges'] + [{ 'id' => 'e3', 'source' => 'n3', 'target' => 'fantasma' }]
    )

    expect { tool.call(input) }.to raise_error(Ai::ToolError, /missing node/)
  end

  it 'aceita input com chaves simbólicas' do
    symbolized = valid_input.deep_symbolize_keys

    expect { tool.call(symbolized) }.to change(account.chatbots, :count).by(1)
  end

  it 'expõe os tipos de nó reais do motor no schema — schema e validator não podem divergir' do
    types = described_class::SCHEMA.dig(:properties, :nodes, :items, :properties, :type, :enum)

    expect(types).to eq(Chatbots::FlowValidator::NODE_TYPES)
  end
end
