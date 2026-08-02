require 'rails_helper'

# Espelha spec/services/whatsapp/providers/whatsapp_cloud_service_spec.rb na
# cobertura (texto/mídia/interativo), mas troca o WebMock por um
# instance_double do Whatsapp::BaileysClient — mesmo padrão de
# spec/services/whatsapp/baileys_session_service_spec.rb, já que o client é
# quem fala HTTP com o microserviço baileys-service.
describe Whatsapp::Providers::WhatsappBaileysService do
  subject(:service) { described_class.new(whatsapp_channel: whatsapp_channel) }

  let(:whatsapp_channel) do
    create(:channel_whatsapp,
           provider: 'baileys',
           provider_config: { 'instance_id' => 'instance-1', 'webhook_secret' => 'secret' },
           validate_provider_config: false,
           sync_templates: false)
  end

  let(:client) { instance_double(Whatsapp::BaileysClient) }
  let(:conversation) { create(:conversation, inbox: whatsapp_channel.inbox) }
  let(:message) do
    create(:message, conversation: conversation, message_type: :outgoing, content: 'test', inbox: whatsapp_channel.inbox)
  end

  let(:success_response) { { 'messages' => [{ 'id' => 'wa-message-id' }] } }

  before do
    allow(Whatsapp::BaileysClient).to receive(:new).and_return(client)
  end

  describe '#send_message' do
    context 'when sending a plain text message' do
      it 'posts a text payload and returns the provider message id' do
        allow(client).to receive(:send_message)
          .with('instance-1', { to: '+123456789', type: 'text', text: { body: 'test' } })
          .and_return(success_response)

        expect(service.send_message('+123456789', message)).to eq('wa-message-id')
      end
    end

    context 'when the message has an image attachment' do
      it 'posts an image payload with a caption' do
        attachment = message.attachments.new(account_id: message.account_id, file_type: :image)
        attachment.file.attach(io: Rails.root.join('spec/assets/avatar.png').open, filename: 'avatar.png', content_type: 'image/png')
        allow(client).to receive(:send_message)
          .with('instance-1', hash_including(to: '+123456789', type: 'image', image: hash_including(caption: 'test')))
          .and_return(success_response)

        expect(service.send_message('+123456789', message)).to eq('wa-message-id')
      end
    end

    context 'when the message has a document attachment' do
      it 'posts a document payload with filename and mime type' do
        attachment = message.attachments.new(account_id: message.account_id, file_type: :file)
        attachment.file.attach(io: Rails.root.join('spec/assets/sample.pdf').open, filename: 'sample.pdf', content_type: 'application/pdf')
        expected_document = hash_including(filename: 'sample.pdf', mime_type: 'application/pdf', caption: 'test')
        allow(client).to receive(:send_message)
          .with('instance-1', hash_including(to: '+123456789', type: 'document', document: expected_document))
          .and_return(success_response)

        expect(service.send_message('+123456789', message)).to eq('wa-message-id')
      end
    end

    context 'when the message is an interactive button prompt' do
      it 'posts an interactive payload with the reply buttons' do
        items = [{ 'title' => 'Yes', 'value' => 'yes' }, { 'title' => 'No', 'value' => 'no' }]
        interactive_message = create(:message,
                                     conversation: conversation,
                                     message_type: :outgoing,
                                     content: 'Pick one',
                                     inbox: whatsapp_channel.inbox,
                                     content_type: 'input_select',
                                     content_attributes: { items: items })
        expected_payload = {
          to: '+123456789',
          type: 'interactive',
          interactive: {
            body: { text: 'Pick one' },
            action: { buttons: [{ reply: { id: 'yes', title: 'Yes' } }, { reply: { id: 'no', title: 'No' } }] }
          }
        }
        allow(client).to receive(:send_message).with('instance-1', expected_payload).and_return(success_response)

        expect(service.send_message('+123456789', interactive_message)).to eq('wa-message-id')
      end
    end

    context 'when the microservice returns an error' do
      it 'marks the message as failed and returns nil' do
        allow(client).to receive(:send_message).and_raise(Whatsapp::BaileysClient::ApiError.new('baileys-service 500: boom'))

        expect(service.send_message('+123456789', message)).to be_nil
        expect(message.reload.status).to eq('failed')
        expect(message.reload.external_error).to eq('baileys-service 500: boom')
      end
    end
  end

  describe '#send_template' do
    context 'when the template has an explicit body' do
      it 'sends it as a plain session message' do
        allow(client).to receive(:send_message)
          .with('instance-1', { to: '+123456789', type: 'text', text: { body: 'Hello there' } })
          .and_return(success_response)

        expect(service.send_template('+123456789', { body: 'Hello there' }, message)).to eq('wa-message-id')
      end
    end

    context 'when the template only has processed_params body_text' do
      it 'sends the body_text as the message' do
        allow(client).to receive(:send_message)
          .with('instance-1', { to: '+123456789', type: 'text', text: { body: 'Templated body' } })
          .and_return(success_response)
        template_info = { processed_params: { 'body_text' => 'Templated body' } }

        expect(service.send_template('+123456789', template_info, message)).to eq('wa-message-id')
      end
    end

    context 'when neither body nor body_text is present' do
      it 'falls back to joining the processed param values' do
        allow(client).to receive(:send_message)
          .with('instance-1', { to: '+123456789', type: 'text', text: { body: 'foo bar' } })
          .and_return(success_response)
        template_info = { processed_params: { 'a' => 'foo', 'b' => 'bar' } }

        expect(service.send_template('+123456789', template_info, message)).to eq('wa-message-id')
      end
    end

    context 'when the resolved body is blank' do
      it 'does not call the microservice' do
        allow(client).to receive(:send_message)

        result = service.send_template('+123456789', { processed_params: {} }, message)

        expect(result).to be_nil
        expect(client).not_to have_received(:send_message)
      end
    end
  end

  describe '#validate_provider_config?' do
    context 'when instance_id and webhook_secret are present and there is no proxy url' do
      it 'returns true' do
        expect(service.validate_provider_config?).to be(true)
      end
    end

    context 'when instance_id is missing' do
      let(:whatsapp_channel) do
        create(:channel_whatsapp,
               provider: 'baileys',
               provider_config: { 'webhook_secret' => 'secret' },
               validate_provider_config: false,
               sync_templates: false)
      end

      it 'returns false' do
        expect(service.validate_provider_config?).to be(false)
      end
    end

    context 'when the proxy url has an unsupported scheme' do
      let(:whatsapp_channel) do
        create(:channel_whatsapp,
               provider: 'baileys',
               provider_config: { 'instance_id' => 'instance-1', 'webhook_secret' => 'secret', 'proxy_url' => 'ftp://proxy.local' },
               validate_provider_config: false,
               sync_templates: false)
      end

      it 'returns false' do
        expect(service.validate_provider_config?).to be(false)
      end
    end

    context 'when the proxy url is a valid socks url' do
      let(:whatsapp_channel) do
        create(:channel_whatsapp,
               provider: 'baileys',
               provider_config: { 'instance_id' => 'instance-1', 'webhook_secret' => 'secret', 'proxy_url' => 'socks5://proxy.local:1080' },
               validate_provider_config: false,
               sync_templates: false)
      end

      it 'returns true' do
        expect(service.validate_provider_config?).to be(true)
      end
    end
  end

  describe '#api_headers' do
    it 'delegates to the baileys client' do
      allow(client).to receive(:api_headers).and_return({ 'Authorization' => 'Bearer token' })

      expect(service.api_headers).to eq({ 'Authorization' => 'Bearer token' })
    end
  end

  describe '#media_url' do
    it 'delegates to the baileys client with the instance id' do
      allow(client).to receive(:media_url).with('instance-1', 'media-1').and_return('http://baileys/instances/instance-1/media/media-1')

      expect(service.media_url('media-1')).to eq('http://baileys/instances/instance-1/media/media-1')
    end
  end
end
