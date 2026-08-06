require 'rails_helper'

RSpec.describe Webhooks::BaileysEventsJob do
  let!(:channel) do
    create(:channel_whatsapp,
           provider: 'baileys',
           provider_config: { 'instance_id' => 'instance-1', 'webhook_secret' => 'secret' },
           validate_provider_config: false,
           sync_templates: false)
  end
  let(:process_service) { instance_double(Whatsapp::IncomingMessageBaileysService, perform: true) }

  def build_payload(field, value)
    {
      object: 'whatsapp_business_account',
      entry: [{ id: 'instance-1', changes: [{ field: field, value: value }] }]
    }
  end

  it 'processes regular messages without the echo flag' do
    params = build_payload('messages', { messages: [{ from: '919745786257', id: 'instance-1:MSG1', type: 'text', text: { body: 'oi' } }] })
    allow(Whatsapp::IncomingMessageBaileysService).to receive(:new).and_return(process_service)

    described_class.perform_now(params, 'instance-1')

    expect(Whatsapp::IncomingMessageBaileysService)
      .to have_received(:new).with(inbox: channel.inbox, params: anything, outgoing_echo: false)
  end

  it 'processes smb_message_echoes payloads with outgoing_echo: true' do
    params = build_payload('smb_message_echoes',
                           { message_echoes: [{ from: '1234567891', to: '919745786257', id: 'instance-1:ECHO1', type: 'text',
                                                text: { body: 'respondi do celular' } }] })
    allow(Whatsapp::IncomingMessageBaileysService).to receive(:new).and_return(process_service)

    described_class.perform_now(params, 'instance-1')

    expect(Whatsapp::IncomingMessageBaileysService)
      .to have_received(:new).with(inbox: channel.inbox, params: anything, outgoing_echo: true)
  end

  it 'serializes echoes on the contact mutex using the `to` number' do
    params = build_payload('smb_message_echoes',
                           { message_echoes: [{ from: '1234567891', to: '919745786257', id: 'instance-1:ECHO1', type: 'text',
                                                text: { body: 'oi' } }] })
    job_instance = described_class.new
    mutex_key = format(Redis::Alfred::WHATSAPP_MESSAGE_MUTEX, inbox_id: channel.inbox.id, sender_id: '919745786257')

    allow(Whatsapp::IncomingMessageBaileysService).to receive(:new).and_return(process_service)
    expect(job_instance).to receive(:with_lock).with(mutex_key, 30.seconds).and_yield

    job_instance.perform(params, 'instance-1')
  end

  it 'routes connection events to the session service' do
    params = { object: 'baileys_connection', entry: [{ id: 'instance-1', changes: [{ field: 'connection', value: { status: 'connected' } }] }] }
    session_service = instance_double(Whatsapp::BaileysSessionService, sync_state!: true)
    allow(Whatsapp::BaileysSessionService).to receive(:new).with(channel: channel).and_return(session_service)

    described_class.perform_now(params, 'instance-1')

    expect(session_service).to have_received(:sync_state!).with({ 'status' => 'connected' })
  end

  it 'ignores unknown instance ids' do
    params = build_payload('messages', { messages: [{ from: '919745786257', id: 'x:1', type: 'text', text: { body: 'oi' } }] })
    allow(Whatsapp::IncomingMessageBaileysService).to receive(:new)

    described_class.perform_now(params, 'unknown-instance')

    expect(Whatsapp::IncomingMessageBaileysService).not_to have_received(:new)
  end
end
