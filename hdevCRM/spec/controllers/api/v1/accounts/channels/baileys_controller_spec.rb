require 'rails_helper'

RSpec.describe 'Baileys session API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:channel) do
    create(:channel_whatsapp,
           account: account,
           provider: 'baileys',
           provider_config: { 'instance_id' => 'instance-1', 'webhook_secret' => 'secret' },
           validate_provider_config: false,
           sync_templates: false)
  end
  let(:inbox) { channel.inbox }
  let(:session_service) { instance_double(Whatsapp::BaileysSessionService) }

  before do
    allow(Whatsapp::BaileysSessionService).to receive(:new).and_return(session_service)
  end

  describe 'GET /api/v1/accounts/{account.id}/inboxes/{inbox.id}/baileys_status' do
    it 'returns unauthorized for a signed out user' do
      get baileys_status_api_v1_account_inbox_path(account, inbox)

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns the session snapshot' do
      allow(session_service).to receive(:status).and_return({ 'status' => 'connected', 'jid' => '123@s.whatsapp.net' })

      get baileys_status_api_v1_account_inbox_path(account, inbox),
          headers: admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['status']).to eq('connected')
    end

    it 'returns service unavailable when the microservice is down' do
      allow(session_service).to receive(:status).and_raise(Whatsapp::BaileysClient::ApiError, 'baileys-service 502')

      get baileys_status_api_v1_account_inbox_path(account, inbox),
          headers: admin.create_new_auth_token

      expect(response).to have_http_status(:service_unavailable)
    end

    it 'rejects an inbox that is not a baileys channel' do
      other_inbox = create(:channel_whatsapp, account: account, validate_provider_config: false, sync_templates: false).inbox

      get baileys_status_api_v1_account_inbox_path(account, other_inbox),
          headers: admin.create_new_auth_token

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'forbids an agent from reading the session' do
      get baileys_status_api_v1_account_inbox_path(account, inbox),
          headers: agent.create_new_auth_token

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/inboxes/{inbox.id}/baileys_connect' do
    it 'starts a QR session' do
      allow(session_service).to receive(:connect!).with(use_pairing_code: false).and_return({ 'status' => 'qr' })

      post baileys_connect_api_v1_account_inbox_path(account, inbox),
           headers: admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(session_service).to have_received(:connect!).with(use_pairing_code: false)
    end

    it 'starts a pairing code session' do
      allow(session_service).to receive(:connect!).with(use_pairing_code: true).and_return({ 'status' => 'pairing' })

      post baileys_connect_api_v1_account_inbox_path(account, inbox),
           params: { use_pairing_code: true },
           headers: admin.create_new_auth_token

      expect(session_service).to have_received(:connect!).with(use_pairing_code: true)
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/inboxes/{inbox.id}/baileys_logout' do
    it 'ends the session' do
      allow(session_service).to receive(:logout!)

      post baileys_logout_api_v1_account_inbox_path(account, inbox),
           headers: admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(session_service).to have_received(:logout!)
    end
  end
end
