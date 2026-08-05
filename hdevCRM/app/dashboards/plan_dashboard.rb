require 'administrate/base_dashboard'

class PlanDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    name: Field::String.with_options(searchable: true),
    plan_type: Field::Select.with_options(collection: lambda { |_field|
      [[I18n.t('administrate.values.plan_type.direct'), 'direct'],
       [I18n.t('administrate.values.plan_type.agency'), 'agency']]
    }),
    price_cents: Field::Number,
    currency: Field::String,
    billing_interval: Field::String,
    stripe_price_id: Field::String,
    max_agents: Field::Number,
    max_inboxes: Field::Number,
    max_baileys_instances: Field::Number,
    max_client_accounts: Field::Number,
    ai_monthly_tokens: Field::Number,
    channel_limits: SerializedField,
    # Form edita o jsonb como texto JSON (ver Plan#channel_limits_json=).
    channel_limits_json: Field::String,
    active: Field::Boolean,
    position: Field::Number,
    subscriptions: Field::HasMany,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    name
    plan_type
    price_cents
    active
    position
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    name
    plan_type
    price_cents
    currency
    billing_interval
    stripe_price_id
    max_agents
    max_inboxes
    max_baileys_instances
    max_client_accounts
    ai_monthly_tokens
    channel_limits
    active
    position
    subscriptions
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    name
    plan_type
    price_cents
    currency
    billing_interval
    stripe_price_id
    max_agents
    max_inboxes
    max_baileys_instances
    max_client_accounts
    ai_monthly_tokens
    channel_limits_json
    active
    position
  ].freeze

  COLLECTION_FILTERS = {
    active: ->(resources) { resources.where(active: true) },
    direct: ->(resources) { resources.where(plan_type: :direct) },
    agency: ->(resources) { resources.where(plan_type: :agency) }
  }.freeze

  def display_resource(plan)
    "##{plan.id} #{plan.name}"
  end
end
