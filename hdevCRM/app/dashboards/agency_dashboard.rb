require 'administrate/base_dashboard'

class AgencyDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    name: Field::String.with_options(searchable: true),
    slug: Field::String.with_options(searchable: true),
    custom_domain: Field::String.with_options(searchable: true),
    status: Field::Select.with_options(collection: [%w[Active active], %w[Suspended suspended]]),
    installation_name: Field::String,
    brand_name: Field::String,
    brand_url: Field::String,
    widget_brand_url: Field::String,
    terms_url: Field::String,
    privacy_url: Field::String,
    primary_color: Field::String,
    logo: Field::ActiveStorage.with_options(
      destroy_url: proc do |_namespace, _resource, attachment|
        [:logo_super_admin_agency, { attachment_id: attachment.id }]
      end
    ),
    logo_dark: Field::ActiveStorage.with_options(
      destroy_url: proc do |_namespace, _resource, attachment|
        [:logo_dark_super_admin_agency, { attachment_id: attachment.id }]
      end
    ),
    logo_thumbnail: Field::ActiveStorage.with_options(
      destroy_url: proc do |_namespace, _resource, attachment|
        [:logo_thumbnail_super_admin_agency, { attachment_id: attachment.id }]
      end
    ),
    accounts: Field::HasMany,
    agency_users: Field::HasMany,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    name
    custom_domain
    status
    accounts
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    name
    slug
    custom_domain
    status
    installation_name
    brand_name
    brand_url
    widget_brand_url
    terms_url
    privacy_url
    primary_color
    logo
    logo_dark
    logo_thumbnail
    accounts
    agency_users
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    name
    slug
    custom_domain
    status
    installation_name
    brand_name
    brand_url
    widget_brand_url
    terms_url
    privacy_url
    primary_color
    logo
    logo_dark
    logo_thumbnail
  ].freeze

  COLLECTION_FILTERS = {
    active: ->(resources) { resources.where(status: :active) },
    suspended: ->(resources) { resources.where(status: :suspended) }
  }.freeze

  def display_resource(agency)
    "##{agency.id} #{agency.name}"
  end
end
