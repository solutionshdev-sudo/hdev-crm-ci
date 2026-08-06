# A única fonte de "que modelo essa conta pode usar e por qual conexão".
#
# Cadeia do plano (modelo NÃO é quantidade: plan_allocations não participa):
#   account.subscription.plan (se grants_plan?)
#     ↓ ausente
#   account.agency.subscription.plan (se grants_plan?)
#     ↓ ausente
#   nil = sem gate (grandfathering, "nil = ilimitado" da F6)
#
# Runtime degrada (decisão 2 do design): modelo fora do plano cai pro
# default liberado com warn — downgrade de plano não mata o bot do cliente.
# Plano sem NENHUM modelo liberado = ModelNotAllowedError (estrito).
class Ai::ModelResolver
  Resolution = Struct.new(:model, :connection, :provider_model_id, keyword_init: true)

  pattr_initialize [:account!]

  def resolve!(canonical_id)
    model = pick_model(canonical_id.to_s)
    connection = model.ai_connection
    raise Ai::ModelNotAllowedError, "connection #{connection.id} disabled" unless connection.active?

    Resolution.new(model: model, connection: connection, provider_model_id: model.provider_model_id)
  end

  def allowed_models
    return AiModel.live if plan.nil?

    AiModel.live.joins(:plan_ai_models).where(plan_ai_models: { plan_id: plan.id })
  end

  def allowed?(canonical_id)
    allowed_models.exists?(canonical_id: canonical_id)
  end

  private

  def pick_model(canonical_id)
    requested = AiModel.live.find_by(canonical_id: canonical_id)
    return degrade(canonical_id) if requested.nil?
    return requested if plan.nil? || allowed?(requested.canonical_id)

    degrade(canonical_id)
  end

  def degrade(canonical_id)
    fallback = default_allowed_model
    raise Ai::ModelNotAllowedError, "plan releases no AI model for account #{account.id}" if fallback.nil?

    Rails.logger.warn("Ai::ModelResolver account=#{account.id}: '#{canonical_id}' indisponível, usando '#{fallback.canonical_id}'")
    fallback
  end

  def default_allowed_model
    allowed_models.find_by(default_for_provider: true) || cheapest_allowed
  end

  # Sem default liberado, o mais barato pelo preço vigente decide.
  def cheapest_allowed
    allowed_models.min_by { |model| model.current_price&.input_cents_per_million || Float::INFINITY }
  end

  def plan
    return @plan if defined?(@plan)

    @plan = subscription_plan(account) || subscription_plan(account.agency)
  end

  def subscription_plan(owner)
    subscription = owner&.subscription
    subscription&.grants_plan? ? subscription.plan : nil
  end
end
