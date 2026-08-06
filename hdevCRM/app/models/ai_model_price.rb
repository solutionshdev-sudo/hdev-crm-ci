class AiModelPrice < ApplicationRecord
  belongs_to :ai_model

  validates :input_cents_per_million, :output_cents_per_million,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :effective_from, presence: true

  scope :current, -> { where(superseded_at: nil) }
end
