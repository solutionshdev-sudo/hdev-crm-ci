# Trilha de auditoria do webhook do Stripe — só index/show nas rotas.
class SuperAdmin::StripeWebhookEventsController < SuperAdmin::ApplicationController
  def scoped_resource
    resource_class.order(created_at: :desc)
  end
end
