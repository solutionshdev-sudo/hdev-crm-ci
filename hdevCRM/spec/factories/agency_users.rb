# frozen_string_literal: true

FactoryBot.define do
  factory :agency_user do
    agency
    user
    role { 'administrator' }
  end
end
