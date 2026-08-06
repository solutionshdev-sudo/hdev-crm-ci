class PlanAiModel < ApplicationRecord
  belongs_to :plan
  belongs_to :ai_model

  validates :ai_model_id, uniqueness: { scope: :plan_id }
end
