# O único lugar que responde "pode criar mais um?" pros limites de plano.
#
# Cadeia de resolução, POR CHAVE (chave ausente cai pro degrau seguinte):
#
#   account.plan_allocations            (a agência distribuiu — chave presente
#                                        vence, inclusive null = ilimitado)
#     ↓ chave ausente
#   account.subscription.plan           (venda direta, se grants_plan?)
#     ↓ sem assinatura vigente
#   account.agency.subscription.plan    (revenda — o limite do plano da agência
#                                        vale POR conta; carve-up explícito é
#                                        responsabilidade de plan_allocations)
#     ↓ nada
#   nil = ilimitado (grandfathering de quem não tem plano; nunca bloqueia)
#
# Tokens de IA ficam de fora: Ai::QuotaService é o dono daquele limite (a F6 só
# adicionou o degrau de plan_allocations lá).
class Plan::LimitEnforcer
  RESOURCES = {
    agent: 'max_agents',
    inbox: 'max_inboxes',
    baileys_instance: 'max_baileys_instances',
    client_account: 'max_client_accounts'
  }.freeze

  def initialize(account: nil, agency: nil)
    raise ArgumentError, 'forneça exatamente um: account: ou agency:' unless [account, agency].compact.one?

    @account = account
    @agency = agency
  end

  def allow!(resource, channel_type: nil)
    raise Plan::LimitExceededError, resource unless resource_allowed?(resource)
    raise Plan::LimitExceededError, :channel unless channel_allowed?(channel_type)

    true
  end

  def allow?(resource, channel_type: nil)
    resource_allowed?(resource) && channel_allowed?(channel_type)
  end

  def limit_for(resource)
    resolve(RESOURCES.fetch(resource.to_sym))
  end

  def channel_limit_for(channel_type)
    resolve_channel(channel_type)
  end

  def remaining(resource)
    limit = limit_for(resource)
    return nil if limit.nil?

    [limit - usage_for(resource), 0].max
  end

  private

  def resource_allowed?(resource)
    limit = limit_for(resource)
    limit.nil? || usage_for(resource) < limit
  end

  def channel_allowed?(channel_type)
    return true if channel_type.blank?

    limit = channel_limit_for(channel_type)
    limit.nil? || channel_usage(channel_type) < limit
  end

  def resolve(key)
    if @account
      allocations = @account.plan_allocations || {}
      return normalize(allocations[key]) if allocations.key?(key)
    end

    resolved_plan && normalize(resolved_plan[key])
  end

  def resolve_channel(channel_type)
    allocated = allocated_channel_limits
    return normalize(allocated[channel_type]) if allocated.key?(channel_type)

    limits = resolved_plan&.channel_limits || {}
    limits.key?(channel_type) ? normalize(limits[channel_type]) : nil
  end

  def allocated_channel_limits
    return {} if @account.nil?

    allocated = (@account.plan_allocations || {})['channel_limits']
    allocated.is_a?(Hash) ? allocated : {}
  end

  # Assinatura direta vigente decide sozinha (plano com coluna nula = ilimitado,
  # sem cair pro plano da agência); só a ausência dela sobe a cadeia.
  def resolved_plan
    return @resolved_plan if defined?(@resolved_plan)

    @resolved_plan = if @agency
                       granted_plan(@agency)
                     else
                       granted_plan(@account) || granted_plan(@account.agency)
                     end
  end

  def granted_plan(owner)
    subscription = owner&.subscription
    subscription&.grants_plan? ? subscription.plan : nil
  end

  def usage_for(resource)
    case resource.to_sym
    when :agent then @account.account_users.count
    when :inbox then @account.inboxes.count
    when :baileys_instance then Channel::Whatsapp.where(account_id: @account.id, provider: 'baileys').count
    when :client_account then @agency.accounts.count
    end
  end

  def channel_usage(channel_type)
    @account.inboxes.where(channel_type: channel_type).count
  end

  def normalize(value)
    value&.to_i
  end
end
