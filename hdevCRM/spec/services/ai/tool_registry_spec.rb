require 'rails_helper'

RSpec.describe Ai::ToolRegistry do
  let(:account) { create(:account) }

  # Tool fake que expõe o que recebeu no initialize, sem acoplar o spec à
  # lista real de tools do copiloto — molde de spec/services/ai/tool_loop_spec.rb.
  let(:tool_class) do
    Class.new(Ai::Tool) do
      declare name: 'fazer', description: 'tool de teste', schema: { type: 'object', properties: {} }

      def call(_input) = 'feito'

      def received_conversation
        conversation
      end
    end
  end

  # Nomes de propriedade declarados em QUALQUER profundidade do schema (um
  # `properties` aninhado dentro de `items`, por exemplo, também conta).
  def property_names(node)
    case node
    when Hash
      node.flat_map do |key, value|
        aqui = key.to_s == 'properties' && value.is_a?(Hash) ? value.keys.map(&:to_s) : []
        aqui + property_names(value)
      end
    when Array then node.flat_map { |item| property_names(item) }
    else []
    end
  end

  def registry(context: :copilot, conversation: nil)
    stub_const('Ai::ToolRegistry::SETS', { context => [tool_class].freeze }.freeze)
    described_class.new(context: context, account: account, conversation: conversation)
  end

  it 'repassa a conversation recebida pras tools que instancia' do
    conversation = create(:conversation, account: account)

    tool = registry(conversation: conversation).tools.first

    expect(tool.received_conversation).to eq(conversation)
  end

  it 'sem conversation continua instanciando as tools do :copilot normalmente' do
    tool = registry(conversation: nil).tools.first

    expect(tool.received_conversation).to be_nil
  end

  it 'levanta UnknownContextError pra SETS desconhecido' do
    stub_const('Ai::ToolRegistry::SETS', { copilot: [tool_class].freeze }.freeze)

    expect { described_class.new(context: :inexistente, account: account).tools }
      .to raise_error(described_class::UnknownContextError, /inexistente/)
  end

  # F3a: o set :agent deixa de ser vazio — cinco tools de negócio/contato/
  # conversa, todas com o escopo vindo só do contexto injetado.
  describe 'SETS[:agent]' do
    let(:conversation) { create(:conversation, account: account) }

    it 'instancia as cinco tools da fase, na ordem registrada, com a conversation injetada' do
      tools = described_class.new(context: :agent, account: account, conversation: conversation).tools

      expect(tools.map(&:class)).to eq(
        [
          Ai::Tools::AtualizarContato,
          Ai::Tools::CriarNegocio,
          Ai::Tools::EtiquetarConversa,
          Ai::Tools::MoverNegocioDaConversa,
          Ai::Tools::TransferirParaHumano
        ]
      )
    end

    # Coração de segurança da fase: um estranho (WhatsApp, widget) escreve a
    # mensagem que o modelo lê, e nenhuma tool deste set pode expor parâmetro
    # que deixe o modelo apontar pra conversa/contato/negócio/conta de outro
    # cliente.
    #
    # ALLOWLIST, não blacklist de nomes de id: uma lista de `%w[account_id
    # conversation_id ...]` só conhece os nomes que alguém lembrou de escrever —
    # `stage_id`, `id`, e principalmente seletores que nem parecem id
    # (`negocio`, `pipeline`) passariam batido. Comparar por IGUALDADE faz
    # qualquer propriedade nova, com qualquer nome, em qualquer profundidade do
    # schema, quebrar este exemplo e obrigar alguém a decidir na mão se ela
    # deixa o modelo apontar pra fora desta conversa.
    #
    # O que ele NÃO cobre, pra ninguém confundir com prova de segurança: o VALOR
    # que o modelo manda em cada parâmetro (isso é o `with forged ids` no spec
    # de cada tool) e o escopo resolvido por nome dentro da conta (o `resolve_`
    # de cada tool). Aqui só se afirma qual é a superfície declarada.
    it 'o set :agent não expõe nenhum parâmetro além dos revisados' do
      esperados = {
        'atualizar_contato' => %w[nome email],
        'criar_negocio' => %w[etapa],
        'etiquetar_conversa' => %w[etiquetas],
        'mover_negocio_da_conversa' => %w[etapa],
        'transferir_para_humano' => []
      }

      declarados = Ai::ToolRegistry::SETS.fetch(:agent).to_h do |tool_class|
        [tool_class.tool_name, property_names(tool_class.tool_schema)]
      end

      expect(declarados).to eq(esperados)
    end
  end
end
