# frozen_string_literal: true

FactoryBot.define do
  factory :stripe_webhook_event do
    sequence(:stripe_event_id) { |n| "evt_test_#{n}" }
    event_type { 'invoice.paid' }
    payload { { 'id' => 'evt_test', 'type' => 'invoice.paid' } }
    status { 'pending' }
  end
end
