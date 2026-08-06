# Billing da CONTA DIRETA com a plataforma. Herda de Api::BaseController de
# propósito, não de Accounts::BaseController: o guard de suspensão de lá
# barraria exatamente quem precisa chegar aqui (conta suspensa por
# inadimplência pagando pra voltar). A autorização é própria: admin da conta,
# e conta-filha de agência NUNCA vê billing nosso — ela paga a agência por
# fora (403 agency_managed).
class Api::V1::Accounts::SubscriptionsController < Api::BaseController
  before_action :fetch_account
  before_action :ensure_account_admin
  before_action :ensure_direct_account

  rescue_from StripeBilling::Error, with: :render_billing_error

  def checkout
    plan = Plan.find_by(id: params[:plan_id])
    render json: { url: StripeBilling::CheckoutSession.new(owner: @account, plan: plan).call }
  end

  def portal
    render json: { url: StripeBilling::PortalSession.new(owner: @account).call }
  end

  private

  def fetch_account
    @account = Account.find(params[:account_id])
  end

  def ensure_account_admin
    account_user = AccountUser.find_by(account_id: @account.id, user_id: current_user.id, role: :administrator)
    render json: { error: I18n.t('errors.api.common.unauthorized') }, status: :unauthorized if account_user.blank?
  end

  def ensure_direct_account
    return if @account.agency_id.blank?

    render json: { error: I18n.t('errors.subscriptions.agency_managed') }, status: :forbidden
  end

  def render_billing_error(exception)
    render json: { error: exception.message }, status: :unprocessable_entity
  end
end
