require 'rails_helper'

RSpec.describe AiAgentListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account, custom_attributes: { 'ai_agent_enabled' => true }) }
  let(:conversation) { create(:conversation, account: account) }

  def event_for(message)
    Events::Base.new('message.created', Time.zone.now, message: message)
  end

  it 'enqueues a reply job for incoming messages' do
    message = create(:message, conversation: conversation, account: account, inbox: conversation.inbox, message_type: :incoming)
    expect { listener.message_created(event_for(message)) }
      .to have_enqueued_job(Ai::ReplyJob).with(conversation.id)
  end

  it 'ignores outgoing messages' do
    message = create(:message, conversation: conversation, account: account, inbox: conversation.inbox, message_type: :outgoing)
    expect { listener.message_created(event_for(message)) }.not_to have_enqueued_job(Ai::ReplyJob)
  end

  it 'ignores accounts without the agent enabled' do
    disabled_account = create(:account)
    disabled_conversation = create(:conversation, account: disabled_account)
    message = create(:message, conversation: disabled_conversation, account: disabled_account,
                               inbox: disabled_conversation.inbox, message_type: :incoming)
    expect { listener.message_created(event_for(message)) }.not_to have_enqueued_job(Ai::ReplyJob)
  end
end
