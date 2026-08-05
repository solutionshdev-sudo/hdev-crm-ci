require 'rails_helper'

RSpec.describe 'Agency AI Usage API', type: :request do
  let(:agency) { create(:agency) }
  let(:agency_admin) { create(:user) }
  let(:other_user) { create(:user) }

  before do
    create(:agency_user, agency: agency, user: agency_admin)
  end

  describe 'GET /api/v1/agencies/:agency_id/ai_usage' do
    it 'returns unauthorized for users outside the agency' do
      get "/api/v1/agencies/#{agency.id}/ai_usage", headers: other_user.create_new_auth_token
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns aggregated usage per account for the agency admin' do
      account_one = create(:account, agency: agency)
      account_two = create(:account, agency: agency)
      create(:ai_usage_event, account: account_one, input_tokens: 1000, output_tokens: 0)
      create(:ai_usage_event, account: account_two, input_tokens: 500, output_tokens: 500)

      get "/api/v1/agencies/#{agency.id}/ai_usage", headers: agency_admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['summary']['total_tokens']).to eq(2000)
      expect(body['per_account'].size).to eq(2)
      expect(body['per_account'].pluck('account_id')).to contain_exactly(account_one.id, account_two.id)
    end

    it 'does not include usage from accounts of other agencies' do
      outside_account = create(:account, agency: create(:agency))
      create(:ai_usage_event, account: outside_account, input_tokens: 999, output_tokens: 0)

      get "/api/v1/agencies/#{agency.id}/ai_usage", headers: agency_admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['summary']['total_tokens']).to eq(0)
    end
  end
end
