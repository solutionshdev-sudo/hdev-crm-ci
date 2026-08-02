# frozen_string_literal: true

FactoryBot.define do
  factory :deal_pipeline do
    sequence(:name) { |n| "Funil #{n}" }
    account
  end

  factory :deal_stage do
    sequence(:name) { |n| "Etapa #{n}" }
    color { '#64748B' }
    position { 1 }
    probability { 10 }
    stage_type { :open }

    after(:build) do |stage|
      stage.account ||= create(:account)
      stage.deal_pipeline ||= create(:deal_pipeline, account: stage.account)
    end

    trait :won do
      stage_type { :won }
      probability { 100 }
    end

    trait :lost do
      stage_type { :lost }
      probability { 0 }
    end
  end

  factory :deal do
    sequence(:title) { |n| "Negócio #{n}" }
    value { 100.0 }

    after(:build) do |deal|
      deal.account ||= create(:account)
      deal.deal_pipeline ||= create(:deal_pipeline, account: deal.account)
      deal.deal_stage ||= create(:deal_stage, account: deal.account, deal_pipeline: deal.deal_pipeline)
      deal.contact ||= create(:contact, account: deal.account)
    end
  end
end
