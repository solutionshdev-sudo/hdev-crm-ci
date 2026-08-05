require 'rails_helper'

RSpec.describe 'Agencies API', type: :request do
  let(:agency) { create(:agency) }
  let(:agency_admin) { create(:user) }
  let(:other_user) { create(:user) }

  before do
    create(:agency_user, agency: agency, user: agency_admin)
  end

  describe 'GET /api/v1/agencies' do
    it 'lists only the agencies the user administers' do
      create(:agency)

      get '/api/v1/agencies', headers: agency_admin.create_new_auth_token
      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('id')).to eq([agency.id])
    end

    it 'returns an empty list for users without agencies' do
      get '/api/v1/agencies', headers: other_user.create_new_auth_token
      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to eq([])
    end
  end

  describe 'PATCH /api/v1/agencies/:id' do
    it 'updates branding fields for the agency admin' do
      patch "/api/v1/agencies/#{agency.id}",
            params: { brand_name: 'Nova Marca', primary_color: '#ff5500', custom_domain: 'painel.novamarca.com' },
            headers: agency_admin.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      agency.reload
      expect(agency.brand_name).to eq('Nova Marca')
      expect(agency.primary_color).to eq('#ff5500')
      expect(agency.custom_domain).to eq('painel.novamarca.com')
    end

    it 'returns unauthorized for users outside the agency' do
      patch "/api/v1/agencies/#{agency.id}",
            params: { brand_name: 'X' },
            headers: other_user.create_new_auth_token,
            as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/agencies/:id' do
    it 'returns unauthorized when not logged in' do
      get "/api/v1/agencies/#{agency.id}"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns unauthorized for users outside the agency' do
      get "/api/v1/agencies/#{agency.id}", headers: other_user.create_new_auth_token
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns the agency for its admin' do
      get "/api/v1/agencies/#{agency.id}", headers: agency_admin.create_new_auth_token
      expect(response).to have_http_status(:success)
      expect(response.parsed_body['id']).to eq(agency.id)
      expect(response.parsed_body['name']).to eq(agency.name)
    end

    context 'when the agency is suspended (F5-T2 §5.2 painel)' do
      it 'returns unauthorized with the agency suspended message even for its own admin' do
        agency.update!(status: :suspended)

        get "/api/v1/agencies/#{agency.id}", headers: agency_admin.create_new_auth_token
        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body['error']).to eq(I18n.t('errors.api.account.agency_suspended'))
      end
    end

    context 'when the agency is pending_payment (F5-T2 §5.2 painel)' do
      it 'also blocks the panel — unlike the child account guard, pending_payment blocks here too' do
        agency.update!(status: :pending_payment)

        get "/api/v1/agencies/#{agency.id}", headers: agency_admin.create_new_auth_token
        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body['error']).to eq(I18n.t('errors.api.account.agency_suspended'))
      end
    end

    context 'when the agency is active' do
      it 'returns success' do
        get "/api/v1/agencies/#{agency.id}", headers: agency_admin.create_new_auth_token
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'GET /api/v1/agencies/:agency_id/accounts' do
    it 'lists only accounts belonging to the agency' do
      account_in_agency = create(:account, agency: agency)
      create(:account)

      get "/api/v1/agencies/#{agency.id}/accounts", headers: agency_admin.create_new_auth_token
      expect(response).to have_http_status(:success)
      expect(response.parsed_body.map { |account| account['id'] }).to eq([account_in_agency.id])
    end

    it 'returns unauthorized for users outside the agency' do
      get "/api/v1/agencies/#{agency.id}/accounts", headers: other_user.create_new_auth_token
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/agencies/:agency_id/accounts' do
    let(:params) do
      { account_name: 'Cliente Um', email: 'cliente@gmail.com', user_full_name: 'Cliente Um', password: 'Password1!' }
    end

    it 'creates an account linked to the agency with an admin user' do
      post "/api/v1/agencies/#{agency.id}/accounts",
           params: params,
           headers: agency_admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      account = Account.find(response.parsed_body['account']['id'])
      expect(account.agency).to eq(agency)
      expect(account.administrators.map(&:email)).to include('cliente@gmail.com')
    end

    it 'returns unauthorized for users outside the agency' do
      post "/api/v1/agencies/#{agency.id}/accounts",
           params: params,
           headers: other_user.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    context 'with plan limits (F6)' do
      it 'returns payment_required when max_client_accounts is reached' do
        plan = create(:plan, :agency, max_client_accounts: 1)
        create(:subscription, owner: agency, plan: plan, status: 'active')
        create(:account, agency: agency)

        expect do
          post "/api/v1/agencies/#{agency.id}/accounts",
               params: params,
               headers: agency_admin.create_new_auth_token,
               as: :json
        end.not_to change(Account, :count)

        expect(response).to have_http_status(:payment_required)
        expect(response.parsed_body['error']).to eq(I18n.t('errors.plan_limits.client_account'))
      end

      it 'creates the account while under the limit' do
        plan = create(:plan, :agency, max_client_accounts: 1)
        create(:subscription, owner: agency, plan: plan, status: 'active')

        post "/api/v1/agencies/#{agency.id}/accounts",
             params: params,
             headers: agency_admin.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
      end
    end
  end
end
