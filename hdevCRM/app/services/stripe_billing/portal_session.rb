# Abre o Customer Portal do Stripe: upgrade/downgrade/cancelamento/cartão são
# problema do Stripe, e a volta chega por customer.subscription.updated/deleted.
# Pré-requisito operacional (não é código): portal ativado no dashboard do
# Stripe com a feature subscription_update e os products liberados.
class StripeBilling::PortalSession
  def initialize(owner:)
    @owner = owner
  end

  def call
    customer_id = @owner.subscription&.stripe_customer_id
    raise StripeBilling::Error, :no_billing_account if customer_id.blank?

    Stripe::BillingPortal::Session.create(
      customer: customer_id,
      return_url: ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
    ).url
  end
end
