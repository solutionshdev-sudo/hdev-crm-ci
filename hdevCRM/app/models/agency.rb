# == Schema Information
#
# Table name: agencies
#
#  id                :bigint           not null, primary key
#  brand_name        :string
#  brand_url         :string
#  custom_domain     :string
#  installation_name :string
#  name              :string           not null
#  primary_color     :string
#  privacy_url       :string
#  settings          :jsonb            not null
#  slug              :string           not null
#  ssl_settings      :jsonb            not null
#  status            :integer          default("active"), not null
#  terms_url         :string
#  widget_brand_url  :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_agencies_on_custom_domain  (custom_domain) UNIQUE
#  index_agencies_on_slug           (slug) UNIQUE
#  index_agencies_on_status         (status)
#
class Agency < ApplicationRecord
  include Rails.application.routes.url_helpers

  DEFAULT_COLOR = '#00875A'.freeze
  ALLOWED_LOGO_CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp image/svg+xml].freeze

  has_many :accounts, dependent: :nullify
  has_many :agency_users, dependent: :destroy_async
  has_many :users, through: :agency_users
  has_many :ai_usage_events, dependent: :nullify

  has_one_attached :logo
  has_one_attached :logo_dark
  has_one_attached :logo_thumbnail

  enum :status, { active: 0, suspended: 1 }

  before_validation :normalize_domain
  before_validation :ensure_slug

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :custom_domain, uniqueness: true, allow_nil: true
  validates :primary_color, format: { with: /\A#(?:\h{3}|\h{6})\z/ }, allow_blank: true
  validate :acceptable_logos

  # Resolves the tenant for an incoming request host. Mirrors the
  # Portal#custom_domain lookup used by the help center.
  def self.resolve_by_host(host)
    return if host.blank?

    active.find_by(custom_domain: host)
  end

  # Branding values merged over the installation-wide GlobalConfig when a
  # request arrives on this agency's custom domain. Only keys the agency has
  # actually configured are returned, so unset fields fall back to the
  # platform defaults.
  def global_config_overrides
    {
      'INSTALLATION_NAME' => installation_name.presence || name,
      'BRAND_NAME' => brand_name.presence || name,
      'LOGO' => attachment_url(logo),
      'LOGO_DARK' => attachment_url(logo_dark) || attachment_url(logo),
      'LOGO_THUMBNAIL' => attachment_url(logo_thumbnail),
      'BRAND_URL' => brand_url.presence,
      'WIDGET_BRAND_URL' => widget_brand_url.presence || brand_url.presence,
      'TERMS_URL' => terms_url.presence,
      'PRIVACY_URL' => privacy_url.presence
    }.compact
  end

  # Merges this agency's branding over an already fetched GlobalConfig hash,
  # touching only the keys the caller originally requested. No-op for
  # suspended agencies so they fall back to the platform brand.
  def apply_branding(config)
    return config unless active?

    config.merge(global_config_overrides.slice(*config.keys.map(&:to_s)))
  end

  def primary_color_or_default
    primary_color.presence || DEFAULT_COLOR
  end

  # Returns the brand color as a space separated RGB triplet ("39 129 246"),
  # the format used by the runtime design tokens in _next-colors.scss.
  # A positive `darken_percent` mixes towards black for the hover/active shades
  # on a light ground; a negative one mixes towards white, which is what the
  # same tokens need on a dark ground so accent text stays readable.
  def brand_rgb(darken_percent = 0)
    hex = primary_color_or_default.delete('#')
    hex = hex.chars.map { |char| char * 2 }.join if hex.length == 3
    hex.scan(/../).map { |component| shift_channel(component.hex, darken_percent) }.join(' ')
  end

  private

  def shift_channel(value, darken_percent)
    return (value * (100 - darken_percent) / 100.0).round if darken_percent >= 0

    (value + ((255 - value) * -darken_percent / 100.0)).round
  end

  def attachment_url(attachment)
    return unless attachment.attached?

    url_for(attachment)
  end

  def normalize_domain
    self.custom_domain = custom_domain.presence&.downcase&.strip
  end

  def ensure_slug
    self.slug = name.to_s.parameterize if slug.blank?
  end

  def acceptable_logos
    { logo: logo, logo_dark: logo_dark, logo_thumbnail: logo_thumbnail }.each do |attribute, attachment|
      next unless attachment.attached?

      errors.add(attribute, :too_big) if attachment.byte_size > 15.megabytes
      errors.add(attribute, :filetype_not_supported) unless ALLOWED_LOGO_CONTENT_TYPES.include?(attachment.content_type)
    end
  end
end
