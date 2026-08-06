# Ajuste manual de assinatura (cortesia, drift do Stripe). new/destroy não
# existem nas rotas de propósito: assinatura nasce no checkout e morre pelo
# cancelamento no Stripe.
class SuperAdmin::SubscriptionsController < SuperAdmin::ApplicationController
  def scoped_resource
    resource_class.order(id: :desc)
  end
end
