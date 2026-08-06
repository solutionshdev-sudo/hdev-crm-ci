require 'rails_helper'

RSpec.describe Ai::AnthropicService do
  let(:account) { create(:account) }
  let(:service) { described_class.new(account: account, feature: 'chatbot') }
  let(:api_response) do
    double('anthropic response', usage: double('usage', input_tokens: 10, output_tokens: 5))
  end

  def stub_client
    messages = double('messages')
    client = double('anthropic client', messages: messages)
    allow(service).to receive(:build_client).and_return(client)
    messages
  end

  describe '#raw_chat' do
    it 'sends the provider_model_id on the wire and records the canonical_id' do
      create(:ai_model, canonical_id: 'canonico-1', provider_model_id: 'wire-1')
      messages = stub_client
      expect(messages).to receive(:create).with(hash_including(model: 'wire-1')).and_return(api_response)

      service.raw_chat(messages: [{ role: 'user', content: 'oi' }], model: 'canonico-1')

      expect(AiUsageEvent.last.model).to eq('canonico-1')
    end

    it 'degrades to the plan default when the saved model is out of the plan' do
      allowed = create(:ai_model, canonical_id: 'liberado', provider_model_id: 'wire-liberado')
      blocked = create(:ai_model, canonical_id: 'barrado')
      plan = create(:plan)
      plan.update!(ai_model_ids: [allowed.id])
      create(:subscription, :active, owner: account, plan: plan)

      messages = stub_client
      expect(messages).to receive(:create).with(hash_including(model: 'wire-liberado')).and_return(api_response)

      service.raw_chat(messages: [{ role: 'user', content: 'oi' }], model: blocked.canonical_id)
    end

    it 'raises the rescuable error when the plan releases nothing' do
      plan = create(:plan)
      create(:subscription, :active, owner: account, plan: plan)

      expect do
        service.raw_chat(messages: [{ role: 'user', content: 'oi' }])
      end.to raise_error(Ai::ModelNotAllowedError)
    end
  end
end
