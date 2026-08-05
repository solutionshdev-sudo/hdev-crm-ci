require 'rails_helper'

RSpec.describe 'Account AI Usage API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  describe 'GET /api/v1/accounts/{account.id}/ai_usage' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/ai_usage"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an agent' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/ai_usage", headers: agent.create_new_auth_token
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an administrator' do
      it 'returns the usage summary' do
        create(:ai_usage_event, account: account, input_tokens: 1000, output_tokens: 500)

        get "/api/v1/accounts/#{account.id}/ai_usage", headers: administrator.create_new_auth_token

        expect(response).to have_http_status(:success)
        body = response.parsed_body
        expect(body['tokens_used']).to eq(1500)
        expect(body['usage']['total_tokens']).to eq(1500)
        expect(body['exceeded']).to be(false)
      end
    end
  end
end
