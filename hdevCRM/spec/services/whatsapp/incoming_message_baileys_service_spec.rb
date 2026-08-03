require 'rails_helper'

# Whatsapp::IncomingMessageBaileysService herda de IncomingMessageWhatsappCloudService
# e só troca download_attachment_file — o payload de webhook e o pipeline de
# ingestão são os mesmos (ver spec/services/whatsapp/incoming_message_whatsapp_cloud_service_spec.rb,
# molde pro setup abaixo). Dois focos: o detector de STOP (Fase 2 §2.2) — ancorado,
# só em texto livre, e a diferença de comportamento entre opt-out e blocked no
# inbound — e a ingestão dos payloads específicos do baileys-service (eco do
# celular via smb_message_echoes e placeholder de conteúdo não suportado).
describe Whatsapp::IncomingMessageBaileysService do
  describe '#perform' do
    after do
      # Coletar antes de deletar — apagar no meio do SCAN pode pular chave (CI 02/08).
      keys = []
      Redis::Alfred.scan_each(match: 'MESSAGE_SOURCE_KEY::*') { |key| keys << key }
      keys.each { |key| Redis::Alfred.delete(key) }
    end

    let!(:whatsapp_channel) do
      create(:channel_whatsapp,
             provider: 'baileys',
             provider_config: { 'instance_id' => 'instance-1', 'webhook_secret' => 'secret' },
             validate_provider_config: false,
             sync_templates: false)
    end

    def text_message_params(body, wa_id: '2423423243', message_id: "wamid.#{SecureRandom.hex(6)}")
      {
        phone_number: whatsapp_channel.phone_number,
        object: 'whatsapp_business_account',
        entry: [{
          changes: [{
            value: {
              contacts: [{ profile: { name: 'Contato Teste' }, wa_id: wa_id }],
              messages: [{ from: wa_id, id: message_id, text: { body: body }, timestamp: '1664799904', type: 'text' }]
            }
          }]
        }]
      }.with_indifferent_access
    end

    def button_reply_params(title, wa_id: '2423423243', message_id: "wamid.#{SecureRandom.hex(6)}")
      {
        phone_number: whatsapp_channel.phone_number,
        object: 'whatsapp_business_account',
        entry: [{
          changes: [{
            value: {
              contacts: [{ profile: { name: 'Contato Teste' }, wa_id: wa_id }],
              messages: [{
                from: wa_id,
                id: message_id,
                timestamp: '1664799904',
                type: 'interactive',
                interactive: { type: 'button_reply', button_reply: { id: 'cancelar', title: title } }
              }]
            }
          }]
        }]
      }.with_indifferent_access
    end

    context 'when the message body is an anchored STOP word' do
      it 'opts the contact out of automation without blocking them' do
        described_class.new(inbox: whatsapp_channel.inbox, params: text_message_params('Pare')).perform

        contact = Contact.last
        expect(contact.automation_opted_out?).to be(true)
        expect(contact.blocked?).to be(false)
      end

      it 'still creates the incoming message — opt-out does not discard inbound like blocked does' do
        described_class.new(inbox: whatsapp_channel.inbox, params: text_message_params('stop')).perform

        expect(whatsapp_channel.inbox.messages.count).to eq(1)
        expect(whatsapp_channel.inbox.messages.first.content).to eq('stop')
      end

      it 'creates the opt-out activity note once the conversation is persisted' do
        allow(Conversations::ActivityMessageJob).to receive(:perform_later)

        described_class.new(inbox: whatsapp_channel.inbox, params: text_message_params('sair')).perform

        conversation = whatsapp_channel.inbox.conversations.last
        expect(Conversations::ActivityMessageJob).to have_received(:perform_later).with(
          conversation, hash_including(content: I18n.t('conversations.activity.opt_out.contact_opted_out'))
        )
      end
    end

    context 'when the free text merely mentions leaving, without matching the anchored regex' do
      it 'does not opt the contact out' do
        described_class.new(inbox: whatsapp_channel.inbox, params: text_message_params('vou sair mais tarde')).perform

        expect(Contact.last.automation_opted_out?).to be(false)
      end
    end

    context 'when the STOP word arrives as an interactive button reply title, not free text' do
      it 'does not opt the contact out — a chatbot menu item called Cancelar is not a STOP command' do
        described_class.new(inbox: whatsapp_channel.inbox, params: button_reply_params('Cancelar')).perform

        expect(Contact.last.automation_opted_out?).to be(false)
        expect(whatsapp_channel.inbox.messages.first.content).to eq('Cancelar')
      end
    end

    context 'when a contact that already opted out sends a new inbound message' do
      it 'still processes it normally, unlike a blocked contact' do
        contact = create(:contact, account: whatsapp_channel.account, automation_opted_out: true, phone_number: '+2423423243')
        create(:contact_inbox, contact: contact, inbox: whatsapp_channel.inbox, source_id: '2423423243')

        described_class.new(inbox: whatsapp_channel.inbox, params: text_message_params('Hello again')).perform

        expect(whatsapp_channel.inbox.messages.count).to eq(1)
        expect(whatsapp_channel.inbox.messages.first.content).to eq('Hello again')
      end

      it 'repeating the STOP word is idempotent — no re-update, no duplicate activity note' do
        allow(Conversations::ActivityMessageJob).to receive(:perform_later)
        contact = create(:contact, account: whatsapp_channel.account, automation_opted_out: true, phone_number: '+2423423243')
        create(:contact_inbox, contact: contact, inbox: whatsapp_channel.inbox, source_id: '2423423243')

        described_class.new(inbox: whatsapp_channel.inbox, params: text_message_params('Pare')).perform

        expect(Conversations::ActivityMessageJob).not_to have_received(:perform_later)
      end
    end

    context 'when a blocked contact sends a new inbound message' do
      it 'discards it, unlike an opted-out contact' do
        contact = create(:contact, account: whatsapp_channel.account, blocked: true, phone_number: '+2423423243')
        create(:contact_inbox, contact: contact, inbox: whatsapp_channel.inbox, source_id: '2423423243')

        described_class.new(inbox: whatsapp_channel.inbox, params: text_message_params('Hello')).perform

        expect(whatsapp_channel.inbox.messages.count).to eq(0)
      end
    end
  end

  # Payloads específicos do baileys-service (pré-traduzidos pro shape do Cloud
  # no Node): eco do celular (field smb_message_echoes) e placeholder de
  # conteúdo não suportado (mídia que falhou no download, contact card, poll).
  describe 'baileys-service payloads (echo + unsupported)' do
    after do
      # Sem esta varredura os locks (ids aleatórios) acumulam no Redis e mudam a
      # geometria do keyspace — foi o que expôs a aresta do SCAN nos cleanups de
      # outros arquivos (CI 02/08). Coletar antes de deletar, pela mesma razão.
      keys = []
      Redis::Alfred.scan_each(match: 'MESSAGE_SOURCE_KEY::*') { |key| keys << key }
      keys.each { |key| Redis::Alfred.delete(key) }
    end

    let!(:channel) do
      create(:channel_whatsapp,
             provider: 'baileys',
             provider_config: { 'instance_id' => 'instance-1', 'webhook_secret' => 'secret' },
             validate_provider_config: false,
             sync_templates: false)
    end
    let(:inbox) { channel.inbox }

    def wrap(field, value)
      {
        object: 'whatsapp_business_account',
        entry: [{ id: 'instance-1', changes: [{ field: field, value: value }] }]
      }.with_indifferent_access
    end

    def echo_params(message)
      wrap('smb_message_echoes', { messaging_product: 'whatsapp',
                                   metadata: { display_phone_number: '1234567891', phone_number_id: 'instance-1' },
                                   message_echoes: [message] })
    end

    describe 'echo ingestion (message sent from the account phone)' do
      # source_id único por exemplo: o MessageDedupLock vive no Redis com TTL de
      # 1 dia e não é limpo entre exemplos — repetir o id bloqueia o segundo spec.
      let(:source_id) { "instance-1:ECHO-#{SecureRandom.hex(4)}" }
      let(:message) do
        { from: '1234567891', to: '919745786257', id: source_id, timestamp: '1722400000',
          type: 'text', text: { body: 'respondi do celular' } }
      end

      it 'creates an outgoing message with no sender, already delivered' do
        described_class.new(inbox: inbox, params: echo_params(message), outgoing_echo: true).perform

        created = inbox.messages.last
        expect(created.message_type).to eq('outgoing')
        expect(created.status).to eq('delivered')
        expect(created.sender).to be_nil
        expect(created.content).to eq('respondi do celular')
        expect(created.source_id).to eq(source_id)
        expect(created.content_attributes['external_echo']).to be(true)
      end

      it 'attaches the conversation to the contact from the `to` number' do
        described_class.new(inbox: inbox, params: echo_params(message), outgoing_echo: true).perform

        expect(inbox.conversations.last.contact.phone_number).to eq('+919745786257')
      end

      it 'is idempotent on source_id, so echoes of API-sent messages never duplicate' do
        2.times { described_class.new(inbox: inbox, params: echo_params(message), outgoing_echo: true).perform }

        expect(inbox.messages.where(source_id: source_id).count).to eq(1)
      end

      it 'does not opt the contact out when the echoed text is a STOP word — it came from the account phone' do
        stop_echo = message.merge(id: "instance-1:ECHO-#{SecureRandom.hex(4)}", text: { body: 'Pare' })
        described_class.new(inbox: inbox, params: echo_params(stop_echo), outgoing_echo: true).perform

        expect(inbox.conversations.last.contact.automation_opted_out?).to be(false)
      end
    end

    describe 'payload timestamps (history backfill)' do
      def text_params(timestamp:)
        wrap('messages', { messaging_product: 'whatsapp',
                           metadata: { display_phone_number: '1234567891', phone_number_id: 'instance-1' },
                           contacts: [{ profile: { name: 'Cliente' }, wa_id: '919745786257' }],
                           messages: [{ from: '919745786257', id: "instance-1:MSG-#{SecureRandom.hex(4)}",
                                        timestamp: timestamp, type: 'text', text: { body: 'oi' } }.compact] })
      end

      it 'stamps created_at from the payload timestamp, so backfilled history keeps its real time and order' do
        described_class.new(inbox: inbox, params: text_params(timestamp: '1722400000')).perform

        expect(inbox.messages.last.created_at).to eq(Time.zone.at(1_722_400_000))
      end

      it 'clamps a future timestamp (skewed device clock) to now' do
        travel_to Time.zone.local(2026, 8, 2, 12, 0, 0) do
          described_class.new(inbox: inbox, params: text_params(timestamp: 1.hour.from_now.to_i.to_s)).perform

          expect(inbox.messages.last.created_at).to eq(Time.zone.now)
        end
      end

      it 'falls back to processing time when the payload has no timestamp' do
        described_class.new(inbox: inbox, params: text_params(timestamp: nil)).perform

        expect(inbox.messages.last.created_at).to be_within(5.seconds).of(Time.zone.now)
      end
    end

    describe 'unsupported content (failed media download, contact cards, polls)' do
      let(:source_id) { "instance-1:MSG-#{SecureRandom.hex(4)}" }
      let(:params) do
        wrap('messages', { messaging_product: 'whatsapp',
                           metadata: { display_phone_number: '1234567891', phone_number_id: 'instance-1' },
                           contacts: [{ profile: { name: 'Cliente' }, wa_id: '919745786257' }],
                           messages: [{ from: '919745786257', id: source_id, timestamp: '1722400000', type: 'unsupported' }] })
      end

      it 'persists an incoming placeholder instead of dropping the message' do
        described_class.new(inbox: inbox, params: params).perform

        created = inbox.messages.last
        expect(created.message_type).to eq('incoming')
        expect(created.content).to eq(I18n.t('conversations.messages.whatsapp.unsupported_message'))
        expect(created.content_attributes['is_unsupported']).to be(true)
      end
    end
  end
end
