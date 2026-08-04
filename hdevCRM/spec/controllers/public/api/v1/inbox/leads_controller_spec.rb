require 'rails_helper'

RSpec.describe 'Public Inbox Leads API', type: :request do
  let!(:api_channel) { create(:channel_api) }

  let(:lead_params) do
    {
      nome: 'Maria Lead',
      email: 'maria@example.com',
      telefone: '+5511999998888',
      mensagem: 'Quero saber mais sobre o produto',
      external_id: 'zap-123',
      utm_source: 'google',
      utm_campaign: 'black-friday'
    }
  end

  describe 'POST /public/api/v1/inboxes/{identifier}/leads' do
    it 'creates contact and conversation from a JSON payload' do
      post "/public/api/v1/inboxes/#{api_channel.identifier}/leads", params: lead_params, as: :json

      expect(response).to have_http_status(:success)
      data = response.parsed_body

      contact = api_channel.account.contacts.find(data['contact_id'])
      expect(contact.name).to eq('Maria Lead')
      expect(contact.email).to eq('maria@example.com')
      expect(contact.phone_number).to eq('+5511999998888')
      expect(contact.additional_attributes['utm_source']).to eq('google')
      expect(contact.additional_attributes['utm_campaign']).to eq('black-friday')
      expect(contact.additional_attributes['external_id']).to eq('zap-123')

      conversation = api_channel.inbox.conversations.find_by(display_id: data['conversation_id'])
      expect(conversation).to be_present
      expect(conversation.messages.incoming.count).to eq(1)
      expect(conversation.messages.incoming.first.content).to eq('Quero saber mais sobre o produto')
      expect(data['source_id']).to eq("lead:#{lead_params[:external_id]}")
    end

    it 'creates contact and conversation from a form-urlencoded payload' do
      # Sem `as: :json`, o Rack::Test manda como application/x-www-form-urlencoded por padrão.
      post "/public/api/v1/inboxes/#{api_channel.identifier}/leads", params: lead_params

      expect(response).to have_http_status(:success)
      data = response.parsed_body

      contact = api_channel.account.contacts.find(data['contact_id'])
      expect(contact.name).to eq('Maria Lead')

      conversation = api_channel.inbox.conversations.find_by(display_id: data['conversation_id'])
      expect(conversation.messages.incoming.count).to eq(1)
    end

    it 'does not duplicate contact, conversation or message on an identical retry (same external_id)' do
      post "/public/api/v1/inboxes/#{api_channel.identifier}/leads", params: lead_params, as: :json
      post "/public/api/v1/inboxes/#{api_channel.identifier}/leads", params: lead_params, as: :json

      expect(response).to have_http_status(:success)
      expect(api_channel.account.contacts.count).to eq(1)
      expect(api_channel.inbox.conversations.count).to eq(1)
      expect(api_channel.inbox.conversations.first.messages.incoming.count).to eq(1)
    end

    it 'appends a new message to the same open conversation when the retry has a different mensagem' do
      post "/public/api/v1/inboxes/#{api_channel.identifier}/leads", params: lead_params, as: :json
      post "/public/api/v1/inboxes/#{api_channel.identifier}/leads", params: lead_params.merge(mensagem: 'Segunda mensagem'), as: :json

      expect(response).to have_http_status(:success)
      expect(api_channel.account.contacts.count).to eq(1)
      expect(api_channel.inbox.conversations.count).to eq(1)
      expect(api_channel.inbox.conversations.first.messages.incoming.count).to eq(2)
    end

    it 'creates only the contact when mensagem is absent (no conversation, no kanban card)' do
      post "/public/api/v1/inboxes/#{api_channel.identifier}/leads", params: lead_params.except(:mensagem), as: :json

      expect(response).to have_http_status(:success)
      data = response.parsed_body
      expect(data['conversation_id']).to be_nil
      expect(api_channel.inbox.conversations.count).to eq(0)
      expect(api_channel.account.contacts.count).to eq(1)
    end

    it 'creates a separate contact for each request when external_id is absent (no idempotency)' do
      post "/public/api/v1/inboxes/#{api_channel.identifier}/leads", params: lead_params.except(:external_id), as: :json
      post "/public/api/v1/inboxes/#{api_channel.identifier}/leads", params: lead_params.except(:external_id), as: :json

      expect(response).to have_http_status(:success)
      expect(api_channel.account.contacts.count).to eq(2)
    end

    it 'returns 404 for an invalid inbox token' do
      post '/public/api/v1/inboxes/invalid-token/leads', params: lead_params, as: :json

      expect(response).to have_http_status(:not_found)
    end

    # NOTE: não há precedente de spec pra Rack::Attack neste repo (rack_attack.rb
    # está desligado em test: `Rack::Attack.enabled = Rails.env.production? ? ... : false`).
    # O throttle `leads/token` (60/hora por token, ver config/initializers/rack_attack.rb)
    # fica sem teste automatizado por ora — 4 linhas auditáveis a olho nu.
  end
end
