require 'rails_helper'

RSpec.describe Whatsapp::BaileysSessionService do
  let(:channel) do
    create(:channel_whatsapp,
           provider: 'baileys',
           provider_config: { 'instance_id' => 'instance-1', 'webhook_secret' => 'secret' },
           validate_provider_config: false,
           sync_templates: false)
  end
  let(:client) { instance_double(Whatsapp::BaileysClient) }
  let(:service) { described_class.new(channel: channel) }

  before do
    allow(Whatsapp::BaileysClient).to receive(:new).and_return(client)
  end

  describe '#connect!' do
    it 'provisions the instance before connecting so a lost session self-heals' do
      allow(client).to receive(:provision).with(channel)
      allow(client).to receive(:connect).with('instance-1', use_pairing_code: false).and_return({ 'status' => 'qr' })

      expect(service.connect!).to eq({ 'status' => 'qr' })
      expect(client).to have_received(:provision).with(channel).ordered
      expect(client).to have_received(:connect).ordered
    end

    it 'forwards the pairing code preference' do
      allow(client).to receive(:provision)
      allow(client).to receive(:connect).with('instance-1', use_pairing_code: true).and_return({ 'status' => 'pairing' })

      service.connect!(use_pairing_code: true)

      expect(client).to have_received(:connect).with('instance-1', use_pairing_code: true)
    end
  end

  describe '#status' do
    it 'returns the microservice snapshot' do
      allow(client).to receive(:status).with('instance-1').and_return({ 'status' => 'connected' })

      expect(service.status).to eq({ 'status' => 'connected' })
    end

    it 'reports a stopped session instead of raising when the instance is unknown' do
      allow(client).to receive(:status).and_raise(Whatsapp::BaileysClient::NotFoundError)

      expect(service.status).to eq({ 'status' => 'disconnected', 'lastError' => 'not_provisioned' })
    end
  end

  describe '#logout!' do
    it 'marks the channel as disconnected' do
      allow(client).to receive(:logout).with('instance-1')

      service.logout!

      expect(channel.reload.provider_config['connection_state']).to eq('disconnected')
      expect(channel.provider_config['connection_state_updated_at']).to be_present
    end

    it 'still marks the channel as disconnected when the instance is unknown' do
      allow(client).to receive(:logout).and_raise(Whatsapp::BaileysClient::NotFoundError)

      service.logout!

      expect(channel.reload.provider_config['connection_state']).to eq('disconnected')
    end
  end

  describe '#sync_state!' do
    it 'stores the state, the jid and the moment it changed' do
      service.sync_state!({ status: 'connected', jid: '123456789@s.whatsapp.net' })

      config = channel.reload.provider_config
      expect(config['connection_state']).to eq('connected')
      expect(config['connected_jid']).to eq('123456789@s.whatsapp.net')
      expect(config['connection_state_updated_at']).to be_present
    end

    it 'stores the disconnect reason' do
      service.sync_state!({ status: 'disconnected', disconnect_reason: 'logged_out' })

      expect(channel.reload.provider_config['last_disconnect_reason']).to eq('logged_out')
    end
  end
end
