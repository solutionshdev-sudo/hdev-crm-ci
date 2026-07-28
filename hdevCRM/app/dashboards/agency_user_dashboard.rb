require 'administrate/base_dashboard'

class AgencyUserDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    agency: Field::BelongsToSearch.with_options(class_name: 'Agency', searchable: true, searchable_field: [:name, :id], order: 'id DESC'),
    user: Field::BelongsToSearch.with_options(class_name: 'User', searchable: true, searchable_field: [:name, :email, :id], order: 'id DESC'),
    id: Field::Number,
    role: Field::Select.with_options(collection: lambda { |_field|
      AgencyUser.roles.keys.map { |role| [I18n.t("administrate.values.role.#{role}", default: role.titleize), role] }
    }),
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    agency
    user
    role
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    agency
    user
    id
    role
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    agency
    user
    role
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(agency_user)
    "#{AgencyUser.model_name.human} ##{agency_user.id}"
  end
end
