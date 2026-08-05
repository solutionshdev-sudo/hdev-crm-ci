# == Schema Information
#
# Table name: ai_credit_events
#
#  id              :bigint           not null, primary key
#  delta           :bigint           not null
#  description     :string
#  owner_type      :string           not null
#  reason          :integer          default("topup"), not null
#  stripe_event_id :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  created_by_id   :bigint
#  owner_id        :bigint           not null
#
# Indexes
#
#  index_ai_credit_events_on_owner_type_and_owner_id  (owner_type,owner_id)
#  index_ai_credit_events_on_stripe_event_id          (stripe_event_id) UNIQUE WHERE (stripe_event_id IS NOT NULL)
#
class AiCreditEvent < ApplicationRecord
  belongs_to :owner, polymorphic: true

  enum :reason, { topup: 0, manual_grant: 1, consumption: 2 }

  validates :delta, numericality: { only_integer: true, other_than: 0 }
  validates :stripe_event_id, uniqueness: true, allow_nil: true

  # Grava o lançamento no ledger e atualiza o saldo (ai_extra_tokens) do dono
  # na mesma transação. O saldo é denormalizado para leitura O(1) no hot path
  # do QuotaService; o ledger é a fonte de auditoria.
  # `attributes` aceita stripe_event_id, description e created_by_id.
  def self.record!(owner:, delta:, reason:, **attributes)
    transaction do
      event = create!(attributes.merge(owner: owner, delta: delta, reason: reason))
      # update_counters é incremento atômico no banco: dois lançamentos
      # simultâneos não podem sobrescrever o saldo um do outro.
      owner.class.update_counters(owner.id, ai_extra_tokens: delta) # rubocop:disable Rails/SkipsModelValidations
      event
    end
  end
end
