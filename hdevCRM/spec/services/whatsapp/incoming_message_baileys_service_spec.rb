require 'rails_helper'

RSpec.describe Whatsapp::IncomingMessageBaileysService do
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
    let(:message) do
      { from: '1234567891', to: '919745786257', id: 'instance-1:ECHO1', timestamp: '1722400000',
        type: 'text', text: { body: 'respondi do celular' } }
    end

    it 'creates an outgoing message with no sender, already delivered' do
      described_class.new(inbox: inbox, params: echo_params(message), outgoing_echo: true).perform

      created = inbox.messages.last
      expect(created.message_type).to eq('outgoing')
      expect(created.status).to eq('delivered')
      expect(created.sender).to be_nil
      expect(created.content).to eq('respondi do celular')
      expect(created.source_id).to eq('instance-1:ECHO1')
      expect(created.content_attributes['external_echo']).to be(true)
    end

    it 'attaches the conversation to the contact from the `to` number' do
      described_class.new(inbox: inbox, params: echo_params(message), outgoing_echo: true).perform

      expect(inbox.conversations.last.contact.phone_number).to eq('+919745786257')
    end

    it 'is idempotent on source_id, so echoes of API-sent messages never duplicate' do
      2.times { described_class.new(inbox: inbox, params: echo_params(message), outgoing_echo: true).perform }

      expect(inbox.messages.where(source_id: 'instance-1:ECHO1').count).to eq(1)
    end
  end

  describe 'unsupported content (failed media download, contact cards, polls)' do
    let(:params) do
      wrap('messages', { messaging_product: 'whatsapp',
                         metadata: { display_phone_number: '1234567891', phone_number_id: 'instance-1' },
                         contacts: [{ profile: { name: 'Cliente' }, wa_id: '919745786257' }],
                         messages: [{ from: '919745786257', id: 'instance-1:MSG1', timestamp: '1722400000', type: 'unsupported' }] })
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
