require 'rails_helper'

RSpec.describe ChatbotSession do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:chatbot) { create(:chatbot, account: account) }
  let!(:session) { create(:chatbot_session, account: account, chatbot: chatbot, conversation: conversation) }

  describe '#dispatch_flow_status_event' do
    before do
      allow(Rails.configuration.dispatcher).to receive(:dispatch)
    end

    it 'dispatches CHATBOT_FLOW_COMPLETED when the session transitions to completed' do
      session.update!(status: :completed)

      expect(Rails.configuration.dispatcher).to have_received(:dispatch)
        .with(described_class::CHATBOT_FLOW_COMPLETED, kind_of(Time), session: session, conversation: conversation, contact: session.contact)
    end

    it 'dispatches CHATBOT_FLOW_ABORTED when the session transitions to aborted' do
      session.update!(status: :aborted)

      expect(Rails.configuration.dispatcher).to have_received(:dispatch)
        .with(described_class::CHATBOT_FLOW_ABORTED, kind_of(Time), session: session, conversation: conversation, contact: session.contact)
    end

    it 'does not dispatch for a non-terminal status transition' do
      session.update!(status: :waiting_input)

      expect(Rails.configuration.dispatcher).not_to have_received(:dispatch)
    end

    it 'does not dispatch when status stays the same' do
      session.update!(current_node_id: 'node-2')

      expect(Rails.configuration.dispatcher).not_to have_received(:dispatch)
    end

    it 'does not dispatch on creation, even into a terminal status' do
      other_conversation = create(:conversation, account: account)

      create(:chatbot_session, account: account, chatbot: chatbot, conversation: other_conversation, status: :failed)

      expect(Rails.configuration.dispatcher).not_to have_received(:dispatch)
    end
  end
end
