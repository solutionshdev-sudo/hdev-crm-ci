require 'rails_helper'

RSpec.describe 'Account Copilot API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  let(:funil_change) do
    { name: 'criar_funil', input: { name: 'Funil de Vendas', stages: [{ name: 'Novo Lead', probability: 10 }] } }
  end

  describe 'POST /api/v1/accounts/{account.id}/copilot' do
    it 'returns unauthorized for agents' do
      post "/api/v1/accounts/#{account.id}/copilot",
           params: { messages: [{ role: 'user', content: 'cria um funil' }] },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/copilot/apply' do
    it 'returns unauthorized for agents' do
      post "/api/v1/accounts/#{account.id}/copilot/apply",
           params: { changes: [funil_change] },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(account.deal_pipelines.count).to eq(0)
    end

    it 'applies the confirmed changes for administrators' do
      post "/api/v1/accounts/#{account.id}/copilot/apply",
           params: { changes: [funil_change] },
           headers: administrator.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(account.deal_pipelines.count).to eq(1)
      expect(account.deal_pipelines.last.deal_stages.pluck(:name)).to eq(['Novo Lead'])
    end

    it 'rejects a tool name outside the whitelist' do
      post "/api/v1/accounts/#{account.id}/copilot/apply",
           params: { changes: [{ name: 'apagar_conta', input: {} }] },
           headers: administrator.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'never accepts an account_id smuggled through the tool input' do
      other = create(:account)

      post "/api/v1/accounts/#{account.id}/copilot/apply",
           params: { changes: [{ name: 'criar_funil', input: { name: 'Invasão', account_id: other.id } }] },
           headers: administrator.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(other.deal_pipelines.count).to eq(0)
      expect(account.deal_pipelines.count).to eq(1)
    end
  end
end
