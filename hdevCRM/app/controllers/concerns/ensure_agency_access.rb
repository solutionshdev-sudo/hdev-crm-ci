# Resolves the agency from route params and requires the current user to be
# an administrator of that agency. Used by the agency scoped API, which lives
# outside the regular account scope.
module EnsureAgencyAccess
  extend ActiveSupport::Concern

  included do
    before_action :fetch_agency
    before_action :ensure_agency_admin
    before_action :ensure_agency_active
  end

  private

  def fetch_agency
    @agency = Agency.find(params[:agency_id] || params[:id])
  end

  def ensure_agency_admin
    @agency_user = AgencyUser.find_by(agency_id: @agency.id, user_id: current_user.id, role: :administrator)
    render json: { error: I18n.t('errors.api.common.unauthorized') }, status: :unauthorized if @agency_user.blank?
  end

  # Assimetria com o guard das contas filhas (EnsureCurrentAccountHelper):
  # lá só suspended? propaga, aqui pending_payment TAMBÉM bloqueia — o painel
  # é como a própria agência se administra, e o plano (§5.2) pede
  # @agency.active? em vez de !suspended?.
  def ensure_agency_active
    return if @agency.active?

    render json: { error: I18n.t('errors.api.account.agency_suspended') }, status: :unauthorized
  end
end
