# frozen_string_literal: true

FactoryBot.define do
  factory :plan do
    sequence(:name) { |n| "Plano #{n}" }
    plan_type { 'direct' }
    price_cents { 9900 }
    currency { 'brl' }
    billing_interval { 'month' }
    active { true }
    sequence(:position) { |n| n }

    trait :agency do
      plan_type { 'agency' }
      max_client_accounts { 10 }
    end

    trait :with_limits do
      max_agents { 3 }
      max_inboxes { 5 }
      max_baileys_instances { 1 }
      ai_monthly_tokens { 1_000_000 }
    end

    trait :with_stripe_price do
      sequence(:stripe_price_id) { |n| "price_test_#{n}" }
    end
  end
end
