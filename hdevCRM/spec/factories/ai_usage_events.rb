# frozen_string_literal: true

FactoryBot.define do
  factory :ai_usage_event do
    account
    model { 'claude-opus-4-8' }
    input_tokens { 1000 }
    output_tokens { 500 }
    feature { 'chatbot' }
  end
end
