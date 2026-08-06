# Billing da AGÊNCIA com a plataforma. Pula o ensure_agency_active de
# propósito: agência pending_payment (primeira contratação) e suspended
# (inadimplente voltando) PRECISAM alcançar o checkout/portal — pagar é
# justamente o caminho de volta. Admin da agência continua obrigatório.
class Api::V1::Agencies::SubscriptionsController < Api::BaseController
  include EnsureAgencyAccess

  skip_before_action :ensure_agency_active

  rescue_from StripeBilling::Error, with: :render_billing_error

  def checkout
    plan = Plan.find_by(id: params[:plan_id])
    render json: { url: StripeBilling::CheckoutSession.new(owner: @agency, plan: plan).call }
  end

  def portal
    render json: { url: StripeBilling::PortalSession.new(owner: @agency).call }
  end

  private

  def render_billing_error(exception)
    render json: { error: exception.message }, status: :unprocessable_entity
  end
end
