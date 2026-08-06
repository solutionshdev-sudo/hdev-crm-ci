class AiModel < ApplicationRecord
  belongs_to :ai_connection

  validates :canonical_id, presence: true, uniqueness: true
  validates :provider_model_id, :display_name, presence: true

  scope :live, -> { where(deprecated_at: nil) }
end
