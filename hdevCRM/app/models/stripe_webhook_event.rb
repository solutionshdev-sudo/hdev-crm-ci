# == Schema Information
#
# Table name: stripe_webhook_events
#
#  id              :bigint           not null, primary key
#  error           :text
#  event_type      :string           not null
#  payload         :jsonb            not null
#  processed_at    :datetime
#  status          :integer          default("pending"), not null
#  stripe_event_id :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_stripe_webhook_events_on_status_and_created_at  (status,created_at)
#  index_stripe_webhook_events_on_stripe_event_id        (stripe_event_id) UNIQUE
#
class StripeWebhookEvent < ApplicationRecord
  # ignored: evento autêntico que não casa com nada local (assinatura criada
  # direto no dashboard do Stripe, price sem Plan). Fica de auditoria — o
  # super admin resolve na mão pelo SubscriptionDashboard. Valor novo só no
  # fim (enum por posição no banco).
  enum :status, { pending: 0, processed: 1, failed: 2, ignored: 3 }

  validates :stripe_event_id, presence: true, uniqueness: true
  validates :event_type, presence: true

  def mark_processed!
    update!(status: :processed, processed_at: Time.zone.now, error: nil)
  end

  def mark_failed!(message)
    update!(status: :failed, error: message.to_s.truncate(5000))
  end

  def mark_ignored!(reason)
    update!(status: :ignored, processed_at: Time.zone.now, error: reason.to_s.truncate(5000))
  end
end
