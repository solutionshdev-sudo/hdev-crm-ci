# frozen_string_literal: true

FactoryBot.define do
  factory :ai_credit_event do
    association :owner, factory: :account
    delta { 100_000 }
    reason { 'topup' }
  end
end
