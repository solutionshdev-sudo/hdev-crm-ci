# == Schema Information
#
# Table name: ai_usage_events
#
#  id              :bigint           not null, primary key
#  cost            :decimal(12, 8)   default(0.0), not null
#  feature         :string
#  input_tokens    :integer          default(0), not null
#  metadata        :jsonb            not null
#  model           :string           not null
#  output_tokens   :integer          default(0), not null
#  total_tokens    :integer          default(0), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  agency_id       :bigint
#  conversation_id :bigint
#
# Indexes
#
#  index_ai_usage_events_on_account_id                 (account_id)
#  index_ai_usage_events_on_account_id_and_created_at  (account_id,created_at)
#  index_ai_usage_events_on_agency_id                  (agency_id)
#  index_ai_usage_events_on_agency_id_and_created_at   (agency_id,created_at)
#
class AiUsageEvent < ApplicationRecord
  belongs_to :account
  belongs_to :agency, optional: true
  belongs_to :conversation, optional: true

  validates :model, presence: true

  before_validation :set_agency
  before_validation :compute_totals

  after_create :increment_usage_counters
  after_create_commit :enqueue_quota_alert

  scope :in_period, ->(range) { where(created_at: range) }

  def self.record!(account:, model:, input_tokens:, output_tokens:, feature: nil, conversation: nil, metadata: {})
    create!(
      account: account,
      model: model,
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      feature: feature,
      conversation: conversation,
      metadata: metadata
    )
  end

  def self.summary
    {
      input_tokens: sum(:input_tokens),
      output_tokens: sum(:output_tokens),
      total_tokens: sum(:total_tokens),
      cost: sum(:cost).to_f.round(6)
    }
  end

  private

  def set_agency
    self.agency_id ||= account&.agency_id
  end

  def compute_totals
    self.total_tokens = input_tokens.to_i + output_tokens.to_i
    self.cost = Ai::Pricing.cost(model, input_tokens, output_tokens)
  end

  # F7.5: o contador é quem responde a quota no hot path — incrementa na
  # mesma transação do evento (consistência) e o alerta de limiar roda em
  # job pós-commit (o mailer saiu da request). O gatilho mora aqui, não no
  # AnthropicService: qualquer fonte futura de evento alerta também.
  def increment_usage_counters
    period = created_at.in_time_zone.to_date.beginning_of_month
    AiUsageCounter.record!(owner: account, period_start: period, tokens: total_tokens, cost: cost)
    AiUsageCounter.record!(owner: agency, period_start: period, tokens: total_tokens, cost: cost) if agency_id.present?
  end

  def enqueue_quota_alert
    Ai::QuotaAlertJob.perform_later(account_id)
  end
end
