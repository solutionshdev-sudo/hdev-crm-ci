class AiModel < ApplicationRecord
  belongs_to :ai_connection
  has_many :ai_model_prices, dependent: :destroy
  has_many :plan_ai_models, dependent: :destroy
  has_many :plans, through: :plan_ai_models

  validates :canonical_id, presence: true, uniqueness: true
  validates :provider_model_id, :display_name, presence: true

  scope :live, -> { where(deprecated_at: nil) }

  def current_price
    ai_model_prices.find_by(superseded_at: nil)
  end
end
