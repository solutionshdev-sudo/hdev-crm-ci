class DealStage < ApplicationRecord
  belongs_to :account
  belongs_to :deal_pipeline
  has_many :deals, dependent: :restrict_with_error

  enum :stage_type, { open: 0, won: 1, lost: 2 }

  validates :name, presence: true
  validates :color, format: { with: /\A#(?:\h{3}|\h{6})\z/ }
  validates :probability, inclusion: { in: 0..100 }
end
