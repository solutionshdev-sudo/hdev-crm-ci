# Limites do plano (F6) na criação de inbox: teto de caixas, teto por tipo de
# canal e teto de instâncias baileys — a instância nasce junto do canal
# whatsapp provider=baileys criado no #create (provision é callback do model),
# então o guard roda ANTES do canal existir e nada de HTTP externo acontece.
module Api::V1::Accounts::Concerns::PlanLimitGuard
  extend ActiveSupport::Concern

  included do
    before_action :validate_plan_limits, only: [:create]
  end

  private

  def validate_plan_limits
    enforcer = Plan::LimitEnforcer.new(account: Current.account)
    enforcer.allow!(:inbox, channel_type: channel_type_from_params&.name)
    enforcer.allow!(:baileys_instance) if baileys_channel_params?
  end

  def baileys_channel_params?
    params.dig(:channel, :type) == 'whatsapp' && params.dig(:channel, :provider) == 'baileys'
  end
end
