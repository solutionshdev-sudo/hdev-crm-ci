require 'rails_helper'

describe AutomationRuleListener do
  let(:listener) { described_class.instance }
  let!(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:conditions_filter_service) { double }
  let(:condition_match) { double }
  let(:action_service) { double }

  before do
    allow(AutomationRules::ConditionsFilterService).to receive(:new).and_return(conditions_filter_service)
    allow(conditions_filter_service).to receive(:perform).and_return(condition_match)
    allow(AutomationRules::ActionService).to receive(:new).and_return(action_service)
    allow(action_service).to receive(:perform)
  end

  describe 'conversation_created' do
    let!(:automation_rule) { create(:automation_rule, event_name: 'conversation_created', account: account) }
    let(:event) do
      Events::Base.new('conversation_created', Time.zone.now, { conversation: conversation,
                                                                changed_attributes: { status: %w[nil Open] } })
    end

    context 'when matching rules are present' do
      it 'calls AutomationRules::ActionService if conditions match' do
        allow(condition_match).to receive(:present?).and_return(true)
        listener.conversation_created(event)
        expect(AutomationRules::ActionService).to have_received(:new).with(automation_rule, account, conversation)
      end

      it 'does not call AutomationRules::ActionService if conditions do not match' do
        allow(condition_match).to receive(:present?).and_return(false)
        listener.conversation_created(event)
        expect(AutomationRules::ActionService).not_to have_received(:new).with(automation_rule, account, conversation)
      end

      it 'calls AutomationRules::ActionService for each rule when multiple rules are present' do
        create(:automation_rule, event_name: 'conversation_created', account: account)
        allow(condition_match).to receive(:present?).and_return(true)
        listener.conversation_created(event)
        expect(AutomationRules::ActionService).to have_received(:new).twice
      end

      it 'does not call AutomationRules::ActionService if performed by automation' do
        event.data[:performed_by] = automation_rule
        allow(condition_match).to receive(:present?).and_return(true)
        listener.conversation_created(event)
        expect(AutomationRules::ActionService).not_to have_received(:new).with(automation_rule, account, conversation)
      end

      it 'does not call AutomationRules::ActionService if conversation has auto_reply in additional_attributes' do
        conversation.additional_attributes = { 'auto_reply' => true }
        allow(condition_match).to receive(:present?).and_return(true)
        listener.conversation_created(event)
        expect(AutomationRules::ActionService).not_to have_received(:new).with(automation_rule, account, conversation)
      end
    end
  end

  describe 'conversation_updated' do
    let!(:automation_rule) { create(:automation_rule, event_name: 'conversation_updated', account: account) }
    let(:event) do
      Events::Base.new('conversation_updated', Time.zone.now, { conversation: conversation,
                                                                changed_attributes: { status: %w[Resolved Open] } })
    end

    context 'when matching rules are present' do
      it 'calls AutomationRules::ActionService if conditions match' do
        allow(condition_match).to receive(:present?).and_return(true)
        listener.conversation_updated(event)
        expect(AutomationRules::ActionService).to have_received(:new).with(automation_rule, account, conversation)
      end

      it 'does not call AutomationRules::ActionService if conditions do not match' do
        allow(condition_match).to receive(:present?).and_return(false)
        listener.conversation_updated(event)
        expect(AutomationRules::ActionService).not_to have_received(:new).with(automation_rule, account, conversation)
      end

      it 'calls AutomationRules::ActionService for each rule when multiple rules are present' do
        create(:automation_rule, event_name: 'conversation_updated', account: account)
        allow(condition_match).to receive(:present?).and_return(true)
        listener.conversation_updated(event)
        expect(AutomationRules::ActionService).to have_received(:new).twice
      end

      it 'does not call AutomationRules::ActionService if performed by automation' do
        event.data[:performed_by] = automation_rule
        allow(condition_match).to receive(:present?).and_return(true)
        listener.conversation_updated(event)
        expect(AutomationRules::ActionService).not_to have_received(:new).with(automation_rule, account, conversation)
      end
    end
  end

  describe 'conversation_opened' do
    let!(:automation_rule) { create(:automation_rule, event_name: 'conversation_opened', account: account) }
    let(:event) do
      Events::Base.new('conversation_opened', Time.zone.now, { conversation: conversation,
                                                               changed_attributes: { status: %w[Resolved Open] } })
    end

    context 'when matching rules are present' do
      it 'calls AutomationRules::ActionService if conditions match' do
        allow(condition_match).to receive(:present?).and_return(true)
        listener.conversation_opened(event)
        expect(AutomationRules::ActionService).to have_received(:new).with(automation_rule, account, conversation)
      end

      it 'does not call AutomationRules::ActionService if conditions do not match' do
        allow(condition_match).to receive(:present?).and_return(false)
        listener.conversation_opened(event)
        expect(AutomationRules::ActionService).not_to have_received(:new).with(automation_rule, account, conversation)
      end

      it 'calls AutomationRules::ActionService for each rule when multiple rules are present' do
        create(:automation_rule, event_name: 'conversation_opened', account: account)
        allow(condition_match).to receive(:present?).and_return(true)
        listener.conversation_opened(event)
        expect(AutomationRules::ActionService).to have_received(:new).twice
      end

      it 'does not call AutomationRules::ActionService if performed by automation' do
        event.data[:performed_by] = automation_rule
        allow(condition_match).to receive(:present?).and_return(true)
        listener.conversation_opened(event)
        expect(AutomationRules::ActionService).not_to have_received(:new).with(automation_rule, account, conversation)
      end
    end
  end

  describe 'conversation_resolved' do
    let!(:automation_rule) { create(:automation_rule, event_name: 'conversation_resolved', account: account) }
    let(:event) do
      Events::Base.new('conversation_resolved', Time.zone.now, { conversation: conversation,
                                                                 changed_attributes: { status: %w[Snoozed Open] } })
    end

    context 'when matching rules are present' do
      it 'calls AutomationRules::ActionService if conditions match' do
        allow(condition_match).to receive(:present?).and_return(true)
        listener.conversation_resolved(event)
        expect(AutomationRules::ActionService).to have_received(:new).with(automation_rule, account, conversation)
      end

      it 'does not call AutomationRules::ActionService if conditions do not match' do
        allow(condition_match).to receive(:present?).and_return(false)
        listener.conversation_resolved(event)
        expect(AutomationRules::ActionService).not_to have_received(:new).with(automation_rule, account, conversation)
      end

      it 'calls AutomationRules::ActionService for each rule when multiple rules are present' do
        create(:automation_rule, event_name: 'conversation_resolved', account: account)
        allow(condition_match).to receive(:present?).and_return(true)
        listener.conversation_resolved(event)
        expect(AutomationRules::ActionService).to have_received(:new).twice
      end

      it 'does not call AutomationRules::ActionService if performed by automation' do
        event.data[:performed_by] = automation_rule
        allow(condition_match).to receive(:present?).and_return(true)
        listener.conversation_resolved(event)
        expect(AutomationRules::ActionService).not_to have_received(:new).with(automation_rule, account, conversation)
      end
    end
  end

  describe 'message_created' do
    let!(:automation_rule) { create(:automation_rule, event_name: 'message_created', account: account) }
    let!(:message) { create(:message, account: account, conversation: conversation) }
    let(:event) do
      Events::Base.new('message_created', Time.zone.now, { message: message,
                                                           changed_attributes: { content: %w[nil Hi] } })
    end

    context 'when matching rules are present' do
      it 'calls AutomationRules::ActionService if conditions match' do
        allow(condition_match).to receive(:present?).and_return(true)
        listener.message_created(event)
        expect(AutomationRules::ActionService).to have_received(:new).with(automation_rule, account, conversation)
      end

      it 'does not call AutomationRules::ActionService if conditions do not match' do
        allow(condition_match).to receive(:present?).and_return(false)
        listener.message_created(event)
        expect(AutomationRules::ActionService).not_to have_received(:new).with(automation_rule, account, conversation)
      end

      it 'calls AutomationRules::ActionService for each rule when multiple rules are present' do
        create(:automation_rule, event_name: 'message_created', account: account)
        allow(condition_match).to receive(:present?).and_return(true)
        listener.message_created(event)
        expect(AutomationRules::ActionService).to have_received(:new).twice
      end

      it 'does not call AutomationRules::ActionService if performed by automation' do
        event.data[:performed_by] = automation_rule
        allow(condition_match).to receive(:present?).and_return(true)
        listener.message_created(event)
        expect(AutomationRules::ActionService).not_to have_received(:new).with(automation_rule, account, conversation)
      end

      it 'does not call AutomationRules::ActionService if message is activity message' do
        message.update!(message_type: 'activity')
        allow(condition_match).to receive(:present?).and_return(true)
        listener.message_created(event)
        expect(AutomationRules::ActionService).not_to have_received(:new).with(automation_rule, account, conversation)
      end

      it 'does not call AutomationRules::ActionService if message is auto reply email' do
        email_channel = create(:channel_email, account: account)
        email_inbox = create(:inbox, channel: email_channel, account: account)
        email_conversation = create(:conversation, inbox: email_inbox, account: account)
        email_message = create(:message, conversation: email_conversation, account: account, content_attributes: { email: { auto_reply: true } })
        email_event = Events::Base.new('message_created', Time.zone.now, { message: email_message })
        allow(condition_match).to receive(:present?).and_return(true)

        listener.message_created(email_event)
        expect(AutomationRules::ActionService).not_to have_received(:new)
      end

      it 'calls AutomationRules::ActionService if message is a private note' do
        message.update!(private: true)
        allow(condition_match).to receive(:present?).and_return(true)

        listener.message_created(event)

        expect(AutomationRules::ActionService).to have_received(:new).with(automation_rule, account, conversation)
      end

      it 'does not call AutomationRules::ActionService if conditions do not match based on content' do
        message.update!(processed_message_content: 'hi', content: "hi\n\nhello")
        allow(condition_match).to receive(:present?).and_return(false)
        listener.message_created(event)
        expect(AutomationRules::ActionService).not_to have_received(:new).with(automation_rule, account, conversation)
      end

      it 'passes conversation attributes to conditions filter service' do
        conversation.update!(status: :open, priority: :high)
        listener.message_created(event)
        expect(AutomationRules::ConditionsFilterService).to have_received(:new).with(
          automation_rule,
          conversation,
          { message: message, changed_attributes: { content: %w[nil Hi] } }
        )
      end
    end
  end

  describe 'deal_created' do
    let!(:automation_rule) { create(:automation_rule, event_name: 'deal_created', account: account) }
    let(:deal) { create(:deal, account: account, conversation: conversation) }
    let(:event) do
      Events::Base.new('deal_created', Time.zone.now, { deal: deal, changed_attributes: { deal_stage_id: [nil, deal.deal_stage_id] } })
    end

    context 'when matching rules are present' do
      it 'calls AutomationRules::ActionService if conditions match' do
        allow(condition_match).to receive(:present?).and_return(true)
        listener.deal_created(event)
        expect(AutomationRules::ActionService).to have_received(:new).with(automation_rule, account, conversation)
      end

      it 'does not call AutomationRules::ActionService if conditions do not match' do
        allow(condition_match).to receive(:present?).and_return(false)
        listener.deal_created(event)
        expect(AutomationRules::ActionService).not_to have_received(:new).with(automation_rule, account, conversation)
      end

      it 'calls AutomationRules::ActionService for each rule when multiple rules are present' do
        create(:automation_rule, event_name: 'deal_created', account: account)
        allow(condition_match).to receive(:present?).and_return(true)
        listener.deal_created(event)
        expect(AutomationRules::ActionService).to have_received(:new).twice
      end

      it 'passes the conversation and changed attributes to the conditions filter service' do
        listener.deal_created(event)
        expect(AutomationRules::ConditionsFilterService).to have_received(:new).with(
          automation_rule,
          conversation,
          { changed_attributes: { deal_stage_id: [nil, deal.deal_stage_id] } }
        )
      end

      # Ao contrário de conversation_created, deal_created NÃO tem o guard de performed_by_automation:
      # a cadeia de regras que cria negócio -> dispara deal_created -> outra regra reage é intencional (Fase 1, item 3).
      it 'calls AutomationRules::ActionService even when performed by automation' do
        event.data[:performed_by] = automation_rule
        allow(condition_match).to receive(:present?).and_return(true)
        listener.deal_created(event)
        expect(AutomationRules::ActionService).to have_received(:new).with(automation_rule, account, conversation)
      end

      it 'does not call AutomationRules::ActionService if the deal has no conversation' do
        deal_without_conversation = create(:deal, account: account)
        event_without_conversation = Events::Base.new('deal_created', Time.zone.now,
                                                      { deal: deal_without_conversation, changed_attributes: {} })
        allow(condition_match).to receive(:present?).and_return(true)

        listener.deal_created(event_without_conversation)

        expect(AutomationRules::ActionService).not_to have_received(:new)
      end
    end
  end

  describe 'deal_stage_changed' do
    let!(:automation_rule) { create(:automation_rule, event_name: 'deal_stage_changed', account: account) }
    let(:deal) { create(:deal, account: account, conversation: conversation) }
    let(:event) do
      Events::Base.new('deal_stage_changed', Time.zone.now, { deal: deal, changed_attributes: { deal_stage_id: [1, 2] } })
    end

    context 'when matching rules are present' do
      it 'calls AutomationRules::ActionService if conditions match' do
        allow(condition_match).to receive(:present?).and_return(true)
        listener.deal_stage_changed(event)
        expect(AutomationRules::ActionService).to have_received(:new).with(automation_rule, account, conversation)
      end

      it 'does not call AutomationRules::ActionService if conditions do not match' do
        allow(condition_match).to receive(:present?).and_return(false)
        listener.deal_stage_changed(event)
        expect(AutomationRules::ActionService).not_to have_received(:new).with(automation_rule, account, conversation)
      end

      it 'calls AutomationRules::ActionService for each rule when multiple rules are present' do
        create(:automation_rule, event_name: 'deal_stage_changed', account: account)
        allow(condition_match).to receive(:present?).and_return(true)
        listener.deal_stage_changed(event)
        expect(AutomationRules::ActionService).to have_received(:new).twice
      end
    end
  end

  describe 'deal_won' do
    let!(:automation_rule) { create(:automation_rule, event_name: 'deal_won', account: account) }
    let(:deal) { create(:deal, account: account, conversation: conversation) }
    let(:event) do
      Events::Base.new('deal_won', Time.zone.now, { deal: deal, changed_attributes: { deal_stage_id: [1, 2] } })
    end

    context 'when matching rules are present' do
      it 'calls AutomationRules::ActionService if conditions match' do
        allow(condition_match).to receive(:present?).and_return(true)
        listener.deal_won(event)
        expect(AutomationRules::ActionService).to have_received(:new).with(automation_rule, account, conversation)
      end

      it 'does not call AutomationRules::ActionService if conditions do not match' do
        allow(condition_match).to receive(:present?).and_return(false)
        listener.deal_won(event)
        expect(AutomationRules::ActionService).not_to have_received(:new).with(automation_rule, account, conversation)
      end

      it 'calls AutomationRules::ActionService for each rule when multiple rules are present' do
        create(:automation_rule, event_name: 'deal_won', account: account)
        allow(condition_match).to receive(:present?).and_return(true)
        listener.deal_won(event)
        expect(AutomationRules::ActionService).to have_received(:new).twice
      end
    end
  end

  describe 'deal_lost' do
    let!(:automation_rule) { create(:automation_rule, event_name: 'deal_lost', account: account) }
    let(:deal) { create(:deal, account: account, conversation: conversation) }
    let(:event) do
      Events::Base.new('deal_lost', Time.zone.now, { deal: deal, changed_attributes: { deal_stage_id: [1, 2] } })
    end

    context 'when matching rules are present' do
      it 'calls AutomationRules::ActionService if conditions match' do
        allow(condition_match).to receive(:present?).and_return(true)
        listener.deal_lost(event)
        expect(AutomationRules::ActionService).to have_received(:new).with(automation_rule, account, conversation)
      end

      it 'does not call AutomationRules::ActionService if conditions do not match' do
        allow(condition_match).to receive(:present?).and_return(false)
        listener.deal_lost(event)
        expect(AutomationRules::ActionService).not_to have_received(:new).with(automation_rule, account, conversation)
      end

      it 'calls AutomationRules::ActionService for each rule when multiple rules are present' do
        create(:automation_rule, event_name: 'deal_lost', account: account)
        allow(condition_match).to receive(:present?).and_return(true)
        listener.deal_lost(event)
        expect(AutomationRules::ActionService).to have_received(:new).twice
      end
    end
  end
end
