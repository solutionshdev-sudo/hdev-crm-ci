require 'administrate/base_dashboard'

class PlatformBannerDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    banner_message: Field::Text.with_options(truncate: 200),
    banner_type: Field::Select.with_options(collection: lambda { |_field|
      %w[info warning error].map { |type| [I18n.t("administrate.values.banner_type.#{type}"), type] }
    }),
    active: Field::Boolean,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[id banner_message banner_type active created_at].freeze
  SHOW_PAGE_ATTRIBUTES = %i[id banner_message banner_type active created_at updated_at].freeze
  FORM_ATTRIBUTES = %i[banner_message banner_type active].freeze

  def display_resource(platform_banner)
    type = I18n.t("administrate.values.banner_type.#{platform_banner.banner_type}", default: platform_banner.banner_type)
    "Banner ##{platform_banner.id} (#{type})"
  end
end
