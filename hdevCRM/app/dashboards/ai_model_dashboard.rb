require 'administrate/base_dashboard'

class AiModelDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    canonical_id: Field::String.with_options(searchable: true),
    provider_model_id: Field::String,
    ai_connection: Field::BelongsTo,
    display_name: Field::String.with_options(searchable: true),
    description: Field::String,
    context_window: Field::Number,
    supports_tools: Field::Boolean,
    default_for_provider: Field::Boolean,
    deprecated_at: Field::DateTime,
    ai_model_prices: Field::HasMany,
    plans: Field::HasMany,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    canonical_id
    display_name
    ai_connection
    default_for_provider
    deprecated_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    canonical_id
    provider_model_id
    ai_connection
    display_name
    description
    context_window
    supports_tools
    default_for_provider
    deprecated_at
    ai_model_prices
    plans
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    canonical_id
    provider_model_id
    ai_connection
    display_name
    description
    context_window
    supports_tools
    default_for_provider
    deprecated_at
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(ai_model)
    ai_model.canonical_id
  end
end
