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
    # cliente. O sweep varre o schema inteiro (`inspect`, não só o primeiro
    # nível) pra pegar regressão em qualquer profundidade.
    it 'nenhuma tool do set :agent declara parâmetro de id no schema' do
      proibidos = %w[account_id conversation_id contact_id deal_id]

      Ai::ToolRegistry::SETS.fetch(:agent).each do |tool_class|
        schema_texto = tool_class.tool_schema.inspect

        proibidos.each do |proibido|
          expect(schema_texto).not_to include(proibido)
        end
      end
    end
  end
end
