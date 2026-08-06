require 'rails_helper'

RSpec.describe 'Account AI Agent API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  describe 'GET /api/v1/accounts/{account.id}/ai_agent' do
    it 'returns unauthorized for agents' do
      get "/api/v1/accounts/#{account.id}/ai_agent", headers: agent.create_new_auth_token
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns the config for administrators' do
      get "/api/v1/accounts/#{account.id}/ai_agent", headers: administrator.create_new_auth_token
      expect(response).to have_http_status(:success)
      expect(response.parsed_body['ai_agent_enabled']).to be(false)
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/ai_agent' do
    it 'updates the AI agent configuration' do
      patch "/api/v1/accounts/#{account.id}/ai_agent",
            params: { ai_agent_enabled: true, ai_agent_prompt: 'Seja cordial', ai_agent_model: 'claude-sonnet-5' },
            headers: administrator.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['ai_agent_enabled']).to be(true)
      expect(response.parsed_body['ai_agent_prompt']).to eq('Seja cordial')

      account.reload
      expect(account.custom_attributes['ai_agent_enabled']).to be(true)
      expect(account.custom_attributes['ai_agent_model']).to eq('claude-sonnet-5')
    end

    it 'returns unauthorized for agents' do
      patch "/api/v1/accounts/#{account.id}/ai_agent",
            params: { ai_agent_enabled: true },
            headers: agent.create_new_auth_token,
            as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects a model outside the plan with 422 and the I18n message' do
      allowed = create(:ai_model)
      blocked = create(:ai_model)
      plan = create(:plan)
      plan.update!(ai_model_ids: [allowed.id])
      create(:subscription, :active, owner: account, plan: plan)

      patch "/api/v1/accounts/#{account.id}/ai_agent",
            params: { ai_agent_model: blocked.canonical_id },
            headers: administrator.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('This AI model is not included in your plan')
      expect(account.reload.custom_attributes['ai_agent_model']).not_to eq(blocked.canonical_id)
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/ai_agent/models' do
    it 'lists only the models the plan releases' do
      allowed = create(:ai_model, display_name: 'Liberado')
      create(:ai_model, display_name: 'Barrado')
      plan = create(:plan)
      plan.update!(ai_model_ids: [allowed.id])
      create(:subscription, :active, owner: account, plan: plan)

      get "/api/v1/accounts/#{account.id}/ai_agent/models",
          headers: administrator.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('canonical_id')).to contain_exactly(allowed.canonical_id)
    end

    it 'returns unauthorized for agents' do
      get "/api/v1/accounts/#{account.id}/ai_agent/models",
          headers: agent.create_new_auth_token,
          as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
