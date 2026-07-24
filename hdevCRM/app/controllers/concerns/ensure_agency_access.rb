# Resolves the agency from route params and requires the current user to be
# an administrator of that agency. Used by the agency scoped API, which lives
# outside the regular account scope.
module EnsureAgencyAccess
  extend ActiveSupport::Concern

  included do
    before_action :fetch_agency
    before_action :ensure_agency_admin
  end

  private

  def fetch_agency
    @agency = Agency.find(params[:agency_id] || params[:id])
  end

  def ensure_agency_admin
    @agency_user = AgencyUser.find_by(agency_id: @agency.id, user_id: current_user.id, role: :administrator)
    render json: { error: 'Unauthorized' }, status: :unauthorized if @agency_user.blank?
  end
end
