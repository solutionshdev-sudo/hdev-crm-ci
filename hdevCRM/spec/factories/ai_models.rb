# frozen_string_literal: true

FactoryBot.define do
  factory :ai_model do
    ai_connection
    sequence(:canonical_id) { |n| "modelo-teste-#{n}" }
    provider_model_id { canonical_id }
    display_name { "Modelo #{canonical_id}" }
  end

  factory :plan_ai_model do
    plan
    ai_model
  end
end
