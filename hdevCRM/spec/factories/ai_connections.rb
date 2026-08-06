# frozen_string_literal: true

FactoryBot.define do
  factory :ai_connection do
    provider { 'anthropic' }
    modality { 'direct' }
    sequence(:label) { |n| "Conexão #{n}" }
    active { true }
  end
end
