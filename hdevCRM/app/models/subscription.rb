# == Schema Information
#
# Table name: subscriptions
#
#  id                     :bigint           not null, primary key
#  current_period_end     :datetime
#  owner_type             :string           not null
#  status                 :integer          default("pending"), not null
#  stripe_customer_id     :string
#  stripe_subscription_id :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  owner_id               :bigint           not null
#  plan_id                :bigint           not null
#
# Indexes
#
#  index_subscriptions_on_owner_type_and_owner_id    (owner_type,owner_id) UNIQUE
#  index_subscriptions_on_plan_id                    (plan_id)
#  index_subscriptions_on_stripe_customer_id         (stripe_customer_id)
#  index_subscriptions_on_stripe_subscription_id     (stripe_subscription_id) UNIQUE WHERE (stripe_subscription_id IS NOT NULL)
#
class Subscription < ApplicationRecord
  belongs_to :owner, polymorphic: true
  belongs_to :plan

  enum :status, { pending: 0, active: 1, past_due: 2, canceled: 3 }

  validates :owner_id, uniqueness: { scope: :owner_type }
  validates :stripe_subscription_id, uniqueness: true, allow_nil: true

  # past_due mantém o plano válido: o dunning do Stripe ainda está tentando
  # cobrar; a suspensão só acontece em customer.subscription.deleted.
  def grants_plan?
    active? || past_due?
  end

  def activate!(stripe_subscription_id: nil, current_period_end: nil)
    transaction do
      update!(
        {
          status: :active,
          stripe_subscription_id: stripe_subscription_id,
          current_period_end: current_period_end
        }.compact
      )
      reactivate_owner!
    end
  end

  def mark_past_due!
    update!(status: :past_due)
  end

  def cancel!
    transaction do
      update!(status: :canceled)
      owner.update!(status: :suspended) unless owner.suspended?
    end
  end

  private

  # Um pagamento confirmado reativa o dono que estava aguardando pagamento ou
  # suspenso por inadimplência. Suspensão manual por abuso deve ser acompanhada
  # do cancelamento da assinatura no Stripe, senão o próximo invoice.paid reativa.
  def reactivate_owner!
    return if owner.active?

    owner.update!(status: :active)
  end
end
