class AiModelPrice < ApplicationRecord
  belongs_to :ai_model

  validates :input_cents_per_million, :output_cents_per_million,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :effective_from, presence: true

  scope :current, -> { where(superseded_at: nil) }

  # Troca de preço = criar linha nova, nunca editar: a vigente anterior do
  # mesmo modelo é marcada como superseded aqui — AiUsageEvent antigo mantém
  # o custo da época.
  after_create :supersede_previous_current

  private

  def supersede_previous_current
    return if superseded_at.present?

    self.class.current.where(ai_model_id: ai_model_id).where.not(id: id).find_each do |price|
      price.update!(superseded_at: Time.zone.now)
    end
  end
end
