# Mesmo contrato de CustomExceptions::Base (to_hash + http_status), pra reusar
# o render_error_response do RequestExceptionHandler: 402, o status que o
# frontend já trata como "limite do plano" no fluxo de agentes.
class Plan::LimitExceededError < StandardError
  attr_reader :resource

  def initialize(resource)
    @resource = resource
    super(I18n.t("errors.plan_limits.#{resource}"))
  end

  def to_hash
    { error: message }
  end

  def http_status
    :payment_required
  end
end
