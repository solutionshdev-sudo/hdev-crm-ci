require 'administrate/base_dashboard'

class AiModelPriceDashboard < Administrate::BaseDashboard
  # superseded_at fica FORA do form de propósito: preço não se edita — criar
  # um novo supersede o vigente (callback no model). Por isso a rota também
  # não tem edit/update/destroy.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    ai_model: Field::BelongsTo,
    input_cents_per_million: Field::Number,
    output_cents_per_million: Field::Number,
    embedding_cents_per_million: Field::Number,
    effective_from: Field::DateTime,
    superseded_at: Field::DateTime,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    ai_model
    input_cents_per_million
    output_cents_per_million
    effective_from
    superseded_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    ai_model
    input_cents_per_million
    output_cents_per_million
    embedding_cents_per_million
    effective_from
    superseded_at
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    ai_model
    input_cents_per_million
    output_cents_per_million
    embedding_cents_per_million
    effective_from
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(ai_model_price)
    "##{ai_model_price.id} #{ai_model_price.ai_model&.canonical_id}"
  end
end
