require 'rails_helper'

# Whatsapp::IncomingMessageBaileysService herda de IncomingMessageWhatsappCloudService
# e só troca download_attachment_file — o payload de webhook e o pipeline de
# ingestão são os mesmos (ver spec/services/whatsapp/incoming_message_whatsapp_cloud_service_spec.rb,
# molde pro setup abaixo). Foco aqui é o detector de STOP (Fase 2 §2.2): ancorado,
# só em texto livre, e a diferença de comportamento entre opt-out e blocked no inbound.
describe Whatsapp::IncomingMessageBaileysService do
  describe '#perform' do
    after do
      Redis::Alfred.scan_each(match: 'MESSAGE_SOURCE_KEY::*') { |key| Redis::Alfred.delete(key) }
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
end
