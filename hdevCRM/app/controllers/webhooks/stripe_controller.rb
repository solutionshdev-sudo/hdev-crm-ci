# Recebe os webhooks de billing do Stripe (o único lugar que dá chamador a
# Subscription#activate!/#mark_past_due!/#cancel!, via EventHandler).
#
# Idempotência: create_or_find_by! (o índice único em stripe_event_id decide
# corrida de INSERT) + with_lock com re-checagem DENTRO do lock. A mutação e o
# mark_processed! rodam na MESMA transação do lock: crash no meio faz rollback
# dos dois, a linha volta a pending e o retry do Stripe reprocessa limpo. Por
# isso falha inesperada do handler NÃO é capturada aqui — o 500 é o que faz o
# Stripe retentar.
class Webhooks::StripeController < ActionController::API
  # Só esses viram linha; o resto responde 200 mudo (o Stripe manda dezenas de
  # tipos e a tabela não é firehose).
  HANDLED_EVENTS = %w[
    checkout.session.completed
    invoice.paid
    invoice.payment_failed
    customer.subscription.updated
    customer.subscription.deleted
  ].freeze

  def process_payload
    stripe_event = verified_event
    return if performed?
    return head :ok unless HANDLED_EVENTS.include?(stripe_event.type)

    apply(find_or_create_event(stripe_event))
    head :ok
  end

  private

  # construct_event faz o HMAC e a tolerância de timestamp (anti-replay).
  # Segredo ausente = endpoint fechado: 401 até alguém configurar o ENV.
  def verified_event
    secret = ENV.fetch('STRIPE_WEBHOOK_SECRET', nil)
    if secret.blank?
      Rails.logger.warn('[STRIPE] webhook 401: STRIPE_WEBHOOK_SECRET not configured')
      return head :unauthorized
    end

    Stripe::Webhook.construct_event(request.raw_post, request.headers['Stripe-Signature'].to_s, secret)
  rescue Stripe::SignatureVerificationError => e
    Rails.logger.warn("[STRIPE] webhook 401: #{e.message}")
    head :unauthorized
  rescue JSON::ParserError
    head :bad_request
  end

  # find primeiro (create_or_find_by! criaria primeiro e esbarraria na
  # validação de uniqueness do model — RecordInvalid — em todo replay).
  # A corrida de INSERT do mesmo event_id fica pro índice único: o perdedor
  # recarrega a linha vencedora no rescue.
  def find_or_create_event(stripe_event)
    StripeWebhookEvent.find_or_create_by!(stripe_event_id: stripe_event.id) do |event|
      event.event_type = stripe_event.type
      event.payload = stripe_event.to_hash
    end
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    StripeWebhookEvent.find_by!(stripe_event_id: stripe_event.id)
  end

  def apply(event)
    event.with_lock do
      # `next`, não `return`: sair de bloco de transação com return tem
      # semântica escorregadia; next termina o bloco e commita.
      next if event.processed? || event.ignored?

      reason = StripeBilling::EventHandler.new(event).call
      reason ? event.mark_ignored!(reason) : event.mark_processed!
    end
  end
end
