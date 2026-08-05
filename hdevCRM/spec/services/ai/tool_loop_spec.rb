require 'rails_helper'

RSpec.describe Ai::ToolLoop do
  let(:account) { create(:account) }
  let(:messages) { [{ role: 'user', content: 'monta um fluxo' }] }

  # Service falso implementando os quatro seams. Mantém o spec sem rede e
  # documenta o contrato que o service OpenAI/Gemini terá que cumprir.
  # Cada turno da fila é [texto, [[id, nome, input], ...]].
  let(:fake_service_class) do
    Class.new do
      attr_reader :calls, :sent_tools, :tool_results

      def initialize(turns)
        @turns = turns.dup
        @calls = 0
      end

      def raw_chat(messages:, system: nil, tools: nil, model: nil, max_tokens: nil) # rubocop:disable Lint/UnusedMethodArgument
        @calls += 1
        @sent_tools = tools
        @turns.shift || ['fim', []]
      end

      def parse_turn(response)
        text, calls = response
        Ai::ToolLoop::Turn.new(
          text: text,
          tool_calls: calls.map { |id, name, input| Ai::ToolLoop::Call.new(id: id, name: name, input: input) }
        )
      end

      def assistant_turn(response)
        { role: 'assistant', content: response.first }
      end

      def tool_result_turn(results)
        @tool_results = results
        [{ role: 'user', content: results.map(&:to_h) }]
      end
    end
  end

  def fake_service(turns)
    fake_service_class.new(turns)
  end

  def registry_with(tool_class)
    stub_const('Ai::ToolRegistry::SETS', { copilot: [tool_class].freeze }.freeze)
    Ai::ToolRegistry.new(context: :copilot, account: account, user: nil)
  end

  def build_tool(name, &body)
    Class.new(Ai::Tool) do
      declare name: name, description: 'tool de teste', schema: { type: 'object', properties: {} }
      define_method(:call, &body)
    end
  end

  let(:echo_tool) { build_tool('fazer') { |_input| 'feito' } }

  it 'executa a ferramenta com o input do modelo e para quando ele não chama mais' do
    executed = []
    tool = build_tool('fazer') do |input|
      executed << input
      'feito'
    end
    service = fake_service([['pensando', [['t1', 'fazer', { 'x' => 1 }]]], ['pronto', []]])

    result = described_class.new(service: service, registry: registry_with(tool)).run(messages: messages)

    expect(executed).to eq([{ 'x' => 1 }])
    expect(result).to eq('pronto')
  end

  it 'chama o modelo uma vez por iteração — é o que faz a quota contar o loop inteiro' do
    service = fake_service([['', [['t1', 'fazer', {}]]], ['', [['t2', 'fazer', {}]]], ['pronto', []]])

    described_class.new(service: service, registry: registry_with(echo_tool)).run(messages: messages)

    expect(service.calls).to eq(3)
  end

  it 'devolve a mensagem de Ai::ToolError pro modelo em vez de estourar' do
    tool = build_tool('fazer') { |_input| raise Ai::ToolError, 'faltou o nome' }
    service = fake_service([['', [['t1', 'fazer', {}]]], ['corrigido', []]])

    expect { described_class.new(service: service, registry: registry_with(tool)).run(messages: messages) }
      .not_to raise_error
    expect(service.tool_results.first.content).to eq('faltou o nome')
    expect(service.tool_results.first.error).to be(true)
  end

  it 'não vaza detalhe interno quando a ferramenta quebra de forma inesperada' do
    tool = build_tool('fazer') { |_input| raise 'PG::ConnectionBad: senha secreta' }
    service = fake_service([['', [['t1', 'fazer', {}]]], ['ok', []]])
    allow(Rails.logger).to receive(:error)

    described_class.new(service: service, registry: registry_with(tool)).run(messages: messages)

    expect(service.tool_results.first.content).to eq('Erro interno ao executar a ferramenta.')
    expect(service.tool_results.first.error).to be(true)
  end

  it 'reporta ferramenta desconhecida em vez de estourar' do
    service = fake_service([['', [['t1', 'inexistente', {}]]], ['ok', []]])

    described_class.new(service: service, registry: registry_with(echo_tool)).run(messages: messages)

    expect(service.tool_results.first.error).to be(true)
    expect(service.tool_results.first.content).to match(/desconhecida/)
  end

  it 'para em MAX_ITERATIONS quando o modelo chama ferramenta em círculo' do
    service = fake_service(Array.new(20) { ['', [['t', 'fazer', {}]]] })
    allow(Rails.logger).to receive(:warn)

    described_class.new(service: service, registry: registry_with(echo_tool)).run(messages: messages)

    expect(service.calls).to eq(described_class::MAX_ITERATIONS)
  end

  it 'não muta o array de mensagens do chamador' do
    service = fake_service([['', [['t1', 'fazer', {}]]], ['ok', []]])

    described_class.new(service: service, registry: registry_with(echo_tool)).run(messages: messages)

    expect(messages.size).to eq(1)
  end
end
