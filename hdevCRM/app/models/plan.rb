# == Schema Information
#
# Table name: plans
#
#  id                    :bigint           not null, primary key
#  active                :boolean          default(TRUE), not null
#  ai_monthly_tokens     :bigint
#  billing_interval      :string           default("month"), not null
#  currency              :string           default("brl"), not null
#  max_agents            :integer
#  max_baileys_instances :integer
#  max_client_accounts   :integer
#  max_inboxes           :integer
#  name                  :string           not null
#  plan_type             :integer          default("direct"), not null
#  position              :integer          default(0), not null
#  price_cents           :integer          default(0), not null
#  stripe_price_id       :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
# Indexes
#
#  index_plans_on_plan_type_and_active_and_position  (plan_type,active,position)
#  index_plans_on_stripe_price_id                    (stripe_price_id) UNIQUE WHERE (stripe_price_id IS NOT NULL)
#
class Plan < ApplicationRecord
  # Limites com valor nulo significam ilimitado.
  LIMIT_ATTRIBUTES = %w[max_agents max_inboxes max_baileys_instances max_client_accounts ai_monthly_tokens].freeze

  has_many :subscriptions, dependent: :restrict_with_error

  enum :plan_type, { direct: 0, agency: 1 }

  validates :name, presence: true
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :stripe_price_id, uniqueness: true, allow_nil: true
  validates :max_agents, :max_inboxes, :max_baileys_instances, :max_client_accounts, :ai_monthly_tokens,
            numericality: { greater_than_or_equal_to: 0, allow_nil: true }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }
end
