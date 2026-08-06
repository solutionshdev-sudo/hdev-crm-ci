# Aplica um StripeWebhookEvent na Subscription local. Devolve nil quando
# processou, ou uma String com o motivo quando o evento é autêntico mas não
# casa com nada local (o controller grava como ignored). Nunca cria
# Subscription: webhook é superfície pública e não inventa estado de cobrança
# — assinatura feita direto no dashboard do Stripe fica ignored e o super
# admin liga na mão pelo SubscriptionDashboard.
#
# Field paths conferidos na doc da API atual (gem stripe ~> 18): o invoice
# aponta pra assinatura via parent.subscription_details.subscription (o
# invoice.subscription de topo não existe mais), o período de serviço vem de
# lines.data[].period.end, e o current_period_end do subscription mora POR
# ITEM em items.data[].current_period_end.
class StripeBilling::EventHandler
  # Os 8 status do Stripe caem nos nossos 4: canceled/incomplete_expired
  # ficam com o customer.subscription.deleted (evita duplicar a suspensão);
  # incomplete/paused não mudam nada (o pending local já descreve).
  ACTIVATING_STATUSES = %w[active trialing].freeze
  PAST_DUE_STATUSES = %w[past_due unpaid].freeze

  def initialize(event)
    @event = event
  end

  def call
    case @event.event_type
    when 'checkout.session.completed' then handle_checkout_completed
    when 'invoice.paid' then handle_invoice_paid
    when 'invoice.payment_failed' then handle_invoice_failed
    when 'customer.subscription.updated' then handle_subscription_updated
    when 'customer.subscription.deleted' then handle_subscription_deleted
    end
  end

  private

  # Na primeira passada o payload é o hash do SDK (chaves-símbolo); no retry
  # ele volta do jsonb com chaves-string. Normaliza pra ler de um jeito só.
  def object
    @object ||= @event.payload.to_h.deep_stringify_keys.dig('data', 'object') || {}
  end

  def handle_checkout_completed
    subscription = Subscription.find_by(id: object['client_reference_id'])
    return "no local subscription for client_reference_id=#{object['client_reference_id'].inspect}" if subscription.nil?

    subscription.update!(stripe_customer_id: object['customer']) if object['customer'].present?
    subscription.activate!(stripe_subscription_id: object['subscription'])
    nil
  end

  def handle_invoice_paid
    subscription = subscription_from_invoice
    return invoice_orphan_reason if subscription.nil?

    subscription.activate!(current_period_end: invoice_period_end)
    nil
  end

  def handle_invoice_failed
    subscription = subscription_from_invoice
    return invoice_orphan_reason if subscription.nil?

    subscription.mark_past_due!
    nil
  end

  def handle_subscription_updated
    subscription = Subscription.find_by(stripe_subscription_id: object['id'])
    return "no local subscription for #{object['id'].inspect}" if subscription.nil?

    plan_reason = sync_plan(subscription)
    return plan_reason if plan_reason

    period_end = items_period_end
    subscription.update!(current_period_end: period_end) if period_end
    sync_status(subscription)
    nil
  end

  def handle_subscription_deleted
    subscription = Subscription.find_by(stripe_subscription_id: object['id'])
    return "no local subscription for #{object['id'].inspect}" if subscription.nil?

    subscription.cancel!
    nil
  end

  def subscription_from_invoice
    stripe_subscription_id = object.dig('parent', 'subscription_details', 'subscription')
    found = Subscription.find_by(stripe_subscription_id: stripe_subscription_id) if stripe_subscription_id.present?
    return found if found

    Subscription.find_by(stripe_customer_id: object['customer']) if object['customer'].present?
  end

  def invoice_orphan_reason
    "no local subscription for invoice customer=#{object['customer'].inspect}"
  end

  # Troca de plano feita no Customer Portal: o price novo precisa existir num
  # Plan local, senão os limites daqui ficariam órfãos do que o Stripe cobra.
  def sync_plan(subscription)
    price_id = object.dig('items', 'data', 0, 'price', 'id')
    return nil if price_id.blank?

    plan = Plan.find_by(stripe_price_id: price_id)
    return "no local plan for price #{price_id.inspect}" if plan.nil?

    subscription.update!(plan: plan) if subscription.plan_id != plan.id
    nil
  end

  def sync_status(subscription)
    case object['status']
    when *ACTIVATING_STATUSES then subscription.activate!
    when *PAST_DUE_STATUSES then subscription.mark_past_due!
    end
  end

  def invoice_period_end
    max_end = Array(object.dig('lines', 'data')).filter_map { |line| line.dig('period', 'end') }.max
    max_end && Time.zone.at(max_end)
  end

  def items_period_end
    max_end = Array(object.dig('items', 'data')).filter_map { |item| item['current_period_end'] }.max
    max_end && Time.zone.at(max_end)
  end
end
