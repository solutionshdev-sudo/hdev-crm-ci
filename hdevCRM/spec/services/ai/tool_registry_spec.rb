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
end
