class Api::V1::AgenciesController < Api::BaseController
  include EnsureAgencyAccess

  skip_before_action :fetch_agency, :ensure_agency_admin, :ensure_agency_active, only: [:index]

  AGENCY_ATTRIBUTES = %i[id name slug custom_domain status installation_name brand_name
                         brand_url widget_brand_url terms_url privacy_url primary_color].freeze

  # Agencies the current user administers — lets the dashboard discover
  # whether to show the agency panel.
  def index
    render json: current_user.agencies.order(:id).as_json(only: AGENCY_ATTRIBUTES)
  end

  def show
    render json: @agency.as_json(only: AGENCY_ATTRIBUTES)
  end

  def update
    @agency.update!(permitted_params)
    render json: @agency.as_json(only: AGENCY_ATTRIBUTES)
  end

  private

  def permitted_params
    params.permit(:name, :installation_name, :brand_name, :brand_url, :widget_brand_url,
                  :terms_url, :privacy_url, :primary_color, :custom_domain)
  end
end
