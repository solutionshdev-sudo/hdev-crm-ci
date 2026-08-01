class Deal < ApplicationRecord
  belongs_to :account
  belongs_to :deal_pipeline
  belongs_to :deal_stage
  belongs_to :contact
  belongs_to :conversation, optional: true
  belongs_to :assignee, class_name: 'User', optional: true
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :deal_activities, dependent: :destroy_async

  enum :status, { open: 0, won: 1, lost: 2 }

  validates :title, presence: true
  validates :value, numericality: { greater_than_or_equal_to: 0 }
  validate :stage_belongs_to_pipeline

  before_save :apply_stage_outcome, if: :deal_stage_id_changed?
  after_create_commit :log_creation
  after_update_commit :log_changes

  scope :in_pipeline, ->(pipeline_id) { where(deal_pipeline_id: pipeline_id) }

  private

  def stage_belongs_to_pipeline
    return if deal_stage.blank? || deal_pipeline.blank?
    return if deal_stage.deal_pipeline_id == deal_pipeline_id

    errors.add(:deal_stage, I18n.t('errors.models.deal.stage_not_in_pipeline'))
  end

  # Entrar em etapa ganha/perdida fecha o negócio; voltar pra etapa aberta reabre.
  def apply_stage_outcome
    case deal_stage.stage_type
    when 'won'
      self.status = :won
      self.closed_at ||= Time.current
    when 'lost'
      self.status = :lost
      self.closed_at ||= Time.current
    else
      self.status = :open
      self.closed_at = nil
      self.lost_reason = nil
    end
  end

  def log_creation
    deal_activities.create!(account_id: account_id, user_id: created_by_id, activity_type: :created,
                            to_stage_id: deal_stage_id)
    dispatch_deal_event(DEAL_CREATED)
  end

  def log_changes
    log_stage_change if saved_change_to_deal_stage_id?
    log_simple_change(:value_changed, :value) if saved_change_to_value?
    log_simple_change(:assignee_changed, :assignee_id) if saved_change_to_assignee_id?
  end

  def log_stage_change
    from_id, to_id = saved_change_to_deal_stage_id
    activity_type = if won?
                      :won
                    elsif lost?
                      :lost
                    else
                      :stage_changed
                    end
    deal_activities.create!(account_id: account_id, user_id: Current.user&.id, activity_type: activity_type,
                            from_stage_id: from_id, to_stage_id: to_id)
    dispatch_deal_event(stage_change_event(activity_type))
  end

  def stage_change_event(activity_type)
    { won: DEAL_WON, lost: DEAL_LOST }.fetch(activity_type, DEAL_STAGE_CHANGED)
  end

  def log_simple_change(activity_type, attribute)
    from, to = saved_changes[attribute.to_s]
    deal_activities.create!(account_id: account_id, user_id: Current.user&.id, activity_type: activity_type,
                            data: { 'from' => from, 'to' => to })
  end

  def dispatch_deal_event(event)
    Rails.configuration.dispatcher.dispatch(event, Time.zone.now, deal: self, conversation: conversation,
                                            changed_attributes: saved_changes)
  end
end
