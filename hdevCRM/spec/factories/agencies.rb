# frozen_string_literal: true

FactoryBot.define do
  factory :agency do
    sequence(:name) { |n| "Agency #{n}" }
    sequence(:custom_domain) { |n| "painel.agency-#{n}.com" }
    status { 'active' }
  end
end
