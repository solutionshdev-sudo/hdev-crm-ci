require 'rails_helper'

describe '/app/login', type: :request do
  context 'without DEFAULT_LOCALE' do
    it 'renders the dashboard' do
      get '/app/login'
      expect(response).to have_http_status(:success)
    end
  end

  context 'with DEFAULT_LOCALE' do
    it 'renders the dashboard' do
      with_modified_env DEFAULT_LOCALE: 'pt_BR' do
        get '/app/login'
        expect(response).to have_http_status(:success)
        expect(response.body).to include "selectedLocale: 'pt_BR'"
      end
    end
  end

  context 'with non-HTML format' do
    it 'returns not acceptable for JSON with error message' do
      get '/app/login', headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:not_acceptable)
      expect(response.parsed_body).to eq({ 'error' => 'Please use API routes instead of dashboard routes for JSON requests' })
    end
  end

  context 'with an agency custom domain' do
    let!(:agency) do
      create(:agency, custom_domain: 'painel.agencia.com', installation_name: 'Painel Pro', primary_color: '#ff5500')
    end

    it 'overrides branding in globalConfig and injects the brand color' do
      get '/app/login', headers: { 'Host' => 'painel.agencia.com' }
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Painel Pro')
      # #ff5500 vira o token de acento runtime (vueapp.html.erb injeta --blue-9/10/11)
      expect(response.body).to include('--blue-9: 255 85 0 !important')
    end

    it 'does not apply agency branding on other hosts' do
      get '/app/login'
      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('255 85 0')
    end

    it 'does not apply branding for suspended agencies' do
      agency.update!(status: 'suspended')
      get '/app/login', headers: { 'Host' => 'painel.agencia.com' }
      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('255 85 0')
    end
  end

  # Routes are loaded once on app start
  # hence Rails.application.reload_routes! is used in this spec
  # ref : https://stackoverflow.com/a/63584877/939299
  context 'with CW_API_ONLY_SERVER true' do
    it 'returns 404' do
      with_modified_env CW_API_ONLY_SERVER: 'true' do
        Rails.application.reload_routes!
        get '/app/login'
        expect(response).to have_http_status(:not_found)
      end
      Rails.application.reload_routes!
    end
  end
end
