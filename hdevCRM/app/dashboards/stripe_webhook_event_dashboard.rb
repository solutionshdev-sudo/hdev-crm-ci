require 'administrate/base_dashboard'

# Read-only (index/show nas rotas): é a trilha de auditoria do webhook. As
# linhas `ignored` são o caso de interesse — evento autêntico do Stripe que
# não casou com nada local (ex.: assinatura criada direto no dashboard do
# Stripe); o motivo fica em `error` e a solução manual é o SubscriptionDashboard.
class StripeWebhookEventDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    stripe_event_id: Field::String.with_options(searchable: true),
    event_type: Field::String.with_options(searchable: true),
    status: Field::String,
    error: Field::Text,
    payload: SerializedField,
    processed_at: Field::DateTime,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    stripe_event_id
    event_type
    status
    created_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    stripe_event_id
    event_type
    status
    error
    payload
    processed_at
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = [].freeze

  COLLECTION_FILTERS = {
    pending: ->(resources) { resources.where(status: :pending) },
    processed: ->(resources) { resources.where(status: :processed) },
    failed: ->(resources) { resources.where(status: :failed) },
    ignored: ->(resources) { resources.where(status: :ignored) }
  }.freeze

  def display_resource(event)
    "#{event.event_type} (#{event.stripe_event_id})"
  end
end
