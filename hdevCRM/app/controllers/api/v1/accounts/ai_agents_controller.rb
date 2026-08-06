class Api::V1::Accounts::AiAgentsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  def show
    render json: config_json
  end

  def update
    if params[:ai_agent_model].present? && !resolver.allowed?(params[:ai_agent_model])
      return render json: { error: I18n.t('errors.ai_agents.model_not_in_plan') }, status: :unprocessable_entity
    end

    attrs = Current.account.custom_attributes
    permitted_params.each { |key, value| attrs[key] = value }
    Current.account.save!
    render json: config_json
  end

  def models
    render json: resolver.allowed_models.order(:display_name).map { |model|
      { canonical_id: model.canonical_id, display_name: model.display_name, default: model.default_for_provider }
    }
  end

  private

  def resolver
    @resolver ||= Ai::ModelResolver.new(account: Current.account)
  end

  def permitted_params
    params.permit(:ai_agent_enabled, :ai_agent_prompt, :ai_agent_model, ai_agent_inbox_ids: [])
  end

  def config_json
    attrs = Current.account.custom_attributes
    {
      ai_agent_enabled: Ai::AgentReplyService.truthy?(attrs['ai_agent_enabled']),
      ai_agent_prompt: attrs['ai_agent_prompt'],
      ai_agent_model: attrs['ai_agent_model'],
      ai_agent_inbox_ids: attrs['ai_agent_inbox_ids']
    }
  end
end
