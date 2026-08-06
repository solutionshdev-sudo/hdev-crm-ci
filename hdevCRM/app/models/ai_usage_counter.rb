# == Schema Information
#
# Table name: ai_usage_counters
#
#  id           :bigint           not null, primary key
#  cost         :decimal(14, 8)   default(0.0), not null
#  owner_type   :string           not null
#  period_start :date             not null
#  tokens       :bigint           default(0), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  owner_id     :bigint           not null
#
# Indexes
#
#  index_ai_usage_counters_on_owner_and_period  (owner_type,owner_id,period_start) UNIQUE
#
class AiUsageCounter < ApplicationRecord
  belongs_to :owner, polymorphic: true

  # Incremento atômico do consumo do mês — mesmo padrão de
  # AiCreditEvent.record!: update_counters vira "tokens = tokens + N" no
  # banco, então dois eventos simultâneos não sobrescrevem o acumulado.
  # A corrida na CRIAÇÃO da linha é decidida pelo índice único: o perdedor
  # pega RecordNotUnique e o retry acha a linha que o vencedor inseriu.
  # (find_or_create_by!, não create_or_find_by! — armadilha anotada da F7.)
  def self.record!(owner:, period_start:, tokens:, cost:)
    counter = find_or_create_by!(owner: owner, period_start: period_start)
    update_counters(counter.id, tokens: tokens, cost: cost) # rubocop:disable Rails/SkipsModelValidations
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def self.current_for(owner)
    find_by(owner: owner, period_start: Time.zone.today.beginning_of_month)
  end
end
