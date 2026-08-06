require 'administrate/base_dashboard'

class AiConnectionDashboard < Administrate::BaseDashboard
  # api_key/aws_secret_access_key são write-only (Field::Password, só no
  # form); o que aparece em show/collection é masked_api_key — a chave em si
  # nunca é renderizada.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    provider: Field::Select.with_options(collection: lambda { |_field|
      [[I18n.t('administrate.values.provider.anthropic'), 'anthropic'],
       [I18n.t('administrate.values.provider.openai'), 'openai'],
       [I18n.t('administrate.values.provider.google'), 'google']]
    }),
    modality: Field::Select.with_options(collection: lambda { |_field|
      [[I18n.t('administrate.values.modality.direct'), 'direct'],
       [I18n.t('administrate.values.modality.bedrock'), 'bedrock'],
       [I18n.t('administrate.values.modality.vertex'), 'vertex']]
    }),
    label: Field::String.with_options(searchable: true),
    api_key: Field::Password,
    masked_api_key: Field::String,
    region: Field::String,
    aws_access_key_id: Field::String,
    aws_secret_access_key: Field::Password,
    validated_at: Field::DateTime,
    validation_error: Field::String,
    active: Field::Boolean,
    ai_models: Field::HasMany,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    provider
    modality
    label
    masked_api_key
    active
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    provider
    modality
    label
    masked_api_key
    region
    validated_at
    validation_error
    active
    ai_models
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    provider
    modality
    label
    api_key
    region
    aws_access_key_id
    aws_secret_access_key
    active
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(ai_connection)
    ai_connection.label
  end
end
