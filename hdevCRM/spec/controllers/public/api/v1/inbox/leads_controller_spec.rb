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
    it 'creates a contact with the mapped fields and utm_*/external_id in additional_attributes' do
      post "/public/api/v1/inboxes/#{api_channel.identifier}/leads", params: lead_params, as: :json

      expect(response).to have_http_status(:success)
      contact = api_channel.account.contacts.find(response.parsed_body['contact_id'])
      expect(contact.name).to eq('Maria Lead')
      expect(contact.email).to eq('maria@example.com')
      expect(contact.phone_number).to eq('+5511999998888')
      expect(contact.additional_attributes['utm_source']).to eq('google')
      expect(contact.additional_attributes['utm_campaign']).to eq('black-friday')
      expect(contact.additional_attributes['external_id']).to eq('zap-123')
    end

    it 'normalizes a masked BR phone (parens/space/hyphen) into E.164 before creating the contact' do
      post "/public/api/v1/inboxes/#{api_channel.identifier}/leads",
           params: lead_params.merge(telefone: '+55 (11) 99999-8888'), as: :json

      expect(response).to have_http_status(:success)
      contact = api_channel.account.contacts.find(response.parsed_body['contact_id'])
      expect(contact.phone_number).to eq('+5511999998888')
    end

    it 'discards an unrecoverable phone (missing the leading +) and still creates the lead' do
      post "/public/api/v1/inboxes/#{api_channel.identifier}/leads",
           params: lead_params.merge(telefone: '(11) 99999-8888'), as: :json

      expect(response).to have_http_status(:success)
      contact = api_channel.account.contacts.find(response.parsed_body['contact_id'])
      expect(contact.phone_number).to be_nil
    end

    it 'creates a conversation with the mensagem as the first inbound message' do
      post "/public/api/v1/inboxes/#{api_channel.identifier}/leads", params: lead_params, as: :json

      expect(response).to have_http_status(:success)
      conversation = api_channel.inbox.conversations.find_by(display_id: response.parsed_body['conversation_id'])
      expect(conversation).to be_present
      expect(conversation.messages.incoming.count).to eq(1)
      expect(conversation.messages.incoming.first.content).to eq('Quero saber mais sobre o produto')
    end

    it 'returns contact_id/conversation_id/source_id in the response body' do
      post "/public/api/v1/inboxes/#{api_channel.identifier}/leads", params: lead_params, as: :json

      expect(response).to have_http_status(:success)
      data = response.parsed_body
      contact_inbox = api_channel.inbox.contact_inboxes.find_by(source_id: "lead:#{lead_params[:external_id]}")
      expect(data['contact_id']).to eq(contact_inbox.contact_id)
      expect(data['conversation_id']).to eq(contact_inbox.conversations.first.display_id)
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

    it 'reuses a pending conversation (ex.: aberta por bot) e não duplica mensagem em retry idêntico' do
      # Simula o efeito de um bot ativo no inbox (determine_conversation_status
      # faz a conversa nascer `pending`, não `open`) sem precisar de bot de
      # verdade: cria a conversa pending direto no setup, já com a mesma
      # mensagem que o retry vai mandar.
      contact = create(:contact, account: api_channel.account, email: 'pendente@example.com')
      contact_inbox = create(:contact_inbox, contact: contact, inbox: api_channel.inbox, source_id: 'lead:pend-1')
      pending_conversation = create(:conversation, account: api_channel.account, inbox: api_channel.inbox,
                                                   contact: contact, contact_inbox: contact_inbox, status: :pending)
      create(:message, account: api_channel.account, inbox: api_channel.inbox, conversation: pending_conversation,
                       message_type: :incoming, content: lead_params[:mensagem])

      post "/public/api/v1/inboxes/#{api_channel.identifier}/leads",
           params: lead_params.merge(external_id: 'pend-1'), as: :json

      expect(response).to have_http_status(:success)
      expect(api_channel.inbox.conversations.count).to eq(1)
      expect(pending_conversation.reload.messages.incoming.count).to eq(1)
    end

    it 'creates only the contact when mensagem is absent (no conversation, no kanban card)' do
      post "/public/api/v1/inboxes/#{api_channel.identifier}/leads", params: lead_params.except(:mensagem), as: :json

      expect(response).to have_http_status(:success)
      data = response.parsed_body
      expect(data['conversation_id']).to be_nil
      expect(api_channel.inbox.conversations.count).to eq(0)
      expect(api_channel.account.contacts.count).to eq(1)
    end

    it 'creates a separate contact_inbox for each request when external_id is absent (no idempotency)' do
      # Email e telefone variam de propósito: o ContactInboxWithContactBuilder
      # também acha contato existente por email/telefone
      # (find_contact_by_email/find_contact_by_phone_number), e Contact valida
      # os dois como únicos por conta. Usar o mesmo email/telefone nas duas
      # chamadas colidiria com ESSA dedupe (que não depende de external_id) e
      # mascararia o que este teste quer provar: sem external_id, a dedupe por
      # source_id não acontece.
      post "/public/api/v1/inboxes/#{api_channel.identifier}/leads", params: lead_params.except(:external_id), as: :json
      post "/public/api/v1/inboxes/#{api_channel.identifier}/leads",
           params: lead_params.except(:external_id).merge(email: 'outra@example.com', telefone: '+5511988887777'), as: :json

      expect(response).to have_http_status(:success)
      expect(api_channel.account.contacts.count).to eq(2)
    end

    it 'returns 404 for an invalid inbox token' do
      post '/public/api/v1/inboxes/invalid-token/leads', params: lead_params, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'ignores conversation_id/contact_id enviados no corpo (before_actions do pai pulados)' do
      post "/public/api/v1/inboxes/#{api_channel.identifier}/leads",
           params: lead_params.merge(conversation_id: 1, contact_id: 'nao-existe'), as: :json

      expect(response).to have_http_status(:success)
    end

    it 'descarta um valor não-escalar de nome em vez de devolver 500 (nome[a]=b)' do
      post "/public/api/v1/inboxes/#{api_channel.identifier}/leads",
           params: lead_params.merge(nome: { a: 'b' }), as: :json

      expect(response).to have_http_status(:success)
      contact = api_channel.account.contacts.find(response.parsed_body['contact_id'])
      expect(contact.name).not_to eq({ 'a' => 'b' })
    end

    it 'ignora um utm_* não-escalar (Hash) no additional_attributes' do
      post "/public/api/v1/inboxes/#{api_channel.identifier}/leads",
           params: lead_params.merge(utm_medium: { a: 'b' }), as: :json

      expect(response).to have_http_status(:success)
      contact = api_channel.account.contacts.find(response.parsed_body['contact_id'])
      expect(contact.additional_attributes).not_to have_key('utm_medium')
    end

    # NOTE: não há precedente de spec pra Rack::Attack neste repo (rack_attack.rb
    # está desligado em test: `Rack::Attack.enabled = Rails.env.production? ? ... : false`).
    # O throttle `leads/token` (60/hora por token, ver config/initializers/rack_attack.rb)
    # fica sem teste automatizado por ora — 4 linhas auditáveis a olho nu.
  end
end
