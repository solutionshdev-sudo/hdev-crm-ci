# frozen_string_literal: true

FactoryBot.define do
  factory :ai_usage_counter do
    association :owner, factory: :account
    period_start { Time.zone.today.beginning_of_month }
    tokens { 0 }
    cost { 0 }
  end
end
