# frozen_string_literal: true

FactoryBot.define do
  factory :chatbot do
    sequence(:name) { |n| "Chatbot #{n}" }
    status { :active }
    account
  end

  factory :chatbot_session do
    status { :running }

    after(:build) do |session|
      session.account ||= create(:account)
      session.chatbot ||= create(:chatbot, account: session.account)
      session.conversation ||= create(:conversation, account: session.account)
    end
  end
end
