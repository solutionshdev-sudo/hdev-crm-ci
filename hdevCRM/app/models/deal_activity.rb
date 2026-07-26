# Log append-only do negócio (sem updated_at) — alimenta o feed de atividades.
class DealActivity < ApplicationRecord
  belongs_to :deal
  belongs_to :account
  belongs_to :user, optional: true
  belongs_to :from_stage, class_name: 'DealStage', optional: true
  belongs_to :to_stage, class_name: 'DealStage', optional: true

  enum :activity_type, { created: 0, stage_changed: 1, value_changed: 2, assignee_changed: 3,
                         won: 4, lost: 5, note: 6, reopened: 7 }
end
