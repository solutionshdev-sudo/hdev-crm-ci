class Chatbots::Nodes::DealNode < Chatbots::Nodes::BaseNode
  def execute
    create_deal
    [:continue, next_id]
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    session.log_event(:failed, node: node, data: { error: e.message.first(200) })
    [:continue, next_id]
  end

  private

  def create_deal
    account = conversation.account
    pipeline = account.deal_pipelines.find_by(id: data['pipeline_id']) || DealPipeline.ensure_default!(account)
    stage = pipeline.deal_stages.find_by(id: data['stage_id']) || pipeline.deal_stages.order(:position).first

    account.deals.create!(
      deal_pipeline: pipeline,
      deal_stage: stage,
      contact: session.contact || conversation.contact,
      conversation: conversation,
      assignee_id: data['assignee_id'].presence,
      title: interpolate(data['title_template'].presence || conversation.contact&.name.to_s.presence || 'Novo negócio'),
      value: interpolate(data['value_template'].to_s).to_f,
      position: stage.deals.minimum(:position).to_f - 1024,
      lost_reason: (I18n.t('automation.default_lost_reason') if stage.lost?)
    )
  end
end
