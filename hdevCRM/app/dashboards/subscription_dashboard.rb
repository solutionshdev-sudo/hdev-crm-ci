require 'administrate/base_dashboard'

class SubscriptionDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    owner: Field::Polymorphic,
    plan: Field::BelongsTo,
    status: Field::Select.with_options(collection: lambda { |_field|
      [[I18n.t('administrate.values.subscription_status.pending'), 'pending'],
       [I18n.t('administrate.values.subscription_status.active'), 'active'],
       [I18n.t('administrate.values.subscription_status.past_due'), 'past_due'],
       [I18n.t('administrate.values.subscription_status.canceled'), 'canceled']]
    }),
    stripe_customer_id: Field::String,
    stripe_subscription_id: Field::String,
    current_period_end: Field::DateTime,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    owner
    plan
    status
    current_period_end
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    owner
    plan
    status
    stripe_customer_id
    stripe_subscription_id
    current_period_end
    created_at
    updated_at
  ].freeze

  # Só plano e status: os campos do Stripe são espelho do webhook e não se
  # editam na mão. A escrita manual de status continua existindo de propósito
  # (cortesia/ajuste — ver field_hint).
  FORM_ATTRIBUTES = %i[
    plan
    status
  ].freeze

  COLLECTION_FILTERS = {
    pending: ->(resources) { resources.where(status: :pending) },
    active: ->(resources) { resources.where(status: :active) },
    past_due: ->(resources) { resources.where(status: :past_due) },
    canceled: ->(resources) { resources.where(status: :canceled) }
  }.freeze

  def display_resource(subscription)
    "##{subscription.id} #{subscription.owner_type} ##{subscription.owner_id}"
  end
end
