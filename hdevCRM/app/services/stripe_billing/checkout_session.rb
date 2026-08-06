# Abre a sessão de checkout do Stripe pra primeira contratação (ou volta de
# uma cancelada). Troca de plano NÃO passa aqui de propósito: é o Customer
# Portal — recusar quando já há plano vigente fecha a escalada de abrir
# checkout de plano caro, abandonar, e ficar com os limites dele (grants_plan?
# olha status, não pagamento).
class StripeBilling::CheckoutSession
  def initialize(owner:, plan:)
    @owner = owner
    @plan = plan
  end

  def call
    validate!
    subscription = upsert_subscription
    Stripe::Checkout::Session.create(session_params(subscription)).url
  end

  private

  def validate!
    raise StripeBilling::Error, :plan_unavailable if @plan.nil? || !@plan.active? || @plan.stripe_price_id.blank?
    raise StripeBilling::Error, :plan_type_mismatch unless plan_type_matches?
    raise StripeBilling::Error, :already_subscribed if @owner.subscription&.grants_plan?
  end

  def plan_type_matches?
    (@owner.is_a?(Agency) && @plan.agency?) || (@owner.is_a?(Account) && @plan.direct?)
  end

  # Owner tem no máximo uma Subscription (índice único owner_type+owner_id).
  # Reusa a linha existente (pending ou canceled) apontando pro plano escolhido
  # — quem confirma a ativação é o webhook, nunca este service.
  def upsert_subscription
    subscription = Subscription.find_or_initialize_by(owner: @owner)
    subscription.plan = @plan
    subscription.status = :pending
    subscription.save!
    subscription
  end

  # client_reference_id é como o checkout.session.completed acha a Subscription
  # local; a metadata é redundância de auditoria no lado do Stripe.
  def session_params(subscription)
    {
      mode: 'subscription',
      line_items: [{ price: @plan.stripe_price_id, quantity: 1 }],
      client_reference_id: subscription.id.to_s,
      customer: subscription.stripe_customer_id,
      success_url: frontend_url,
      cancel_url: frontend_url,
      subscription_data: { metadata: { owner_type: @owner.class.name, owner_id: @owner.id } }
    }.compact
  end

  def frontend_url
    ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
  end
end
