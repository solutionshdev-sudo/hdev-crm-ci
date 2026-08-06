require 'rails_helper'

RSpec.describe Conversations::AiHandlingFilterService do
  let(:account) { create(:account) }

  describe '#perform' do
    context 'when a conversation has an active chatbot session' do
      it 'includes it, regardless of the account AI agent setting' do
        conversation = create(:conversation, account: account)
        chatbot = create(:chatbot, account: account)
        create(:chatbot_session, account: account, chatbot: chatbot, conversation: conversation, status: :running)

        result = described_class.new(account.conversations, account).perform

        expect(result.map(&:id)).to include(conversation.id)
      end
    end

    context 'when the chatbot session already completed and the AI agent is off' do
      it 'excludes the conversation' do
        conversation = create(:conversation, account: account)
        chatbot = create(:chatbot, account: account)
        create(:chatbot_session, account: account, chatbot: chatbot, conversation: conversation, status: :completed)

        result = described_class.new(account.conversations, account).perform

        expect(result.map(&:id)).not_to include(conversation.id)
      end
    end

    context 'when the AI agent is off and there is no active session' do
      it 'excludes every conversation' do
        create(:conversation, account: account)

        result = described_class.new(account.conversations, account).perform

        expect(result).to be_empty
      end
    end

    context 'when the account has the AI agent enabled' do
      let(:account) { create(:account, custom_attributes: { 'ai_agent_enabled' => true }) }

      it 'includes an eligible unassigned, unresolved conversation' do
        conversation = create(:conversation, account: account)

        result = described_class.new(account.conversations, account).perform

        expect(result.map(&:id)).to include(conversation.id)
      end

      it 'excludes a resolved conversation' do
        conversation = create(:conversation, account: account, status: 'resolved')

        result = described_class.new(account.conversations, account).perform

        expect(result.map(&:id)).not_to include(conversation.id)
      end

      it 'excludes a conversation with an assignee' do
        agent = create(:user, account: account, role: :agent)
        conversation = create(:conversation, account: account, assignee: agent)

        result = described_class.new(account.conversations, account).perform

        expect(result.map(&:id)).not_to include(conversation.id)
      end

      it 'excludes a conversation with ai_agent_handoff marked' do
        conversation = create(:conversation, account: account, custom_attributes: { 'ai_agent_handoff' => true })

        result = described_class.new(account.conversations, account).perform

        expect(result.map(&:id)).not_to include(conversation.id)
      end
    end
  end
end
