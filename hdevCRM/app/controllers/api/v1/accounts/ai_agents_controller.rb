class Api::V1::Accounts::AiAgentsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  def show
    render json: config_json
  end

  def update
    attrs = Current.account.custom_attributes
    permitted_params.each { |key, value| attrs[key] = value }
    Current.account.save!
    render json: config_json
  end

  private

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
