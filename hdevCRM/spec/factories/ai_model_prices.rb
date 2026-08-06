# frozen_string_literal: true

FactoryBot.define do
  factory :ai_model_price do
    ai_model
    input_cents_per_million { 500 }
    output_cents_per_million { 2500 }
    effective_from { Time.zone.now }
  end
end
