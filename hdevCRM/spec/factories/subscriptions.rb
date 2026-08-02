# frozen_string_literal: true

FactoryBot.define do
  factory :subscription do
    association :plan
    association :owner, factory: :account
    status { 'pending' }

    trait :for_agency do
      association :owner, factory: :agency
      association :plan, factory: %i[plan agency]
    end

    trait :active do
      status { 'active' }
      sequence(:stripe_customer_id) { |n| "cus_test_#{n}" }
      sequence(:stripe_subscription_id) { |n| "sub_test_#{n}" }
      current_period_end { 1.month.from_now }
    end
  end
end
