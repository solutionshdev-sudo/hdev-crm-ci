# Mirrors Webhooks::WhatsappEventsJob for the baileys provider. Message and
# status payloads come pre-translated to Meta Cloud API shape, so they flow
# straight into the Cloud ingestion pipeline; connection events update the
# channel's provider_config instead.
class Webhooks::BaileysEventsJob < MutexApplicationJob
  queue_as :low
  retry_on LockAcquisitionError, wait: 2.seconds, attempts: 20

  def perform(params, instance_id)
    params = params.with_indifferent_access
    channel = find_channel(instance_id)
    return if channel.blank? || !channel.account.active?

    if connection_event?(params)
      handle_connection_event(channel, params)
      return
    end

    sender_id = params.dig(:entry, 0, :changes, 0, :value, :messages, 0, :from)
    if sender_id.blank?
      process_messages(channel, params)
      return
    end

    key = format(::Redis::Alfred::WHATSAPP_MESSAGE_MUTEX, inbox_id: channel.inbox.id, sender_id: sender_id)
    with_lock(key, 30.seconds) do
      process_messages(channel, params)
    end
  end

  private

  def find_channel(instance_id)
    Channel::Whatsapp
      .where(provider: 'baileys')
      .find_by("provider_config ->> 'instance_id' = ?", instance_id)
  end

  def connection_event?(params)
    params[:object] == 'baileys_connection'
  end

  def handle_connection_event(channel, params)
    value = params.dig(:entry, 0, :changes, 0, :value)
    return if value.blank?

    Whatsapp::BaileysSessionService.new(channel: channel).sync_state!(value)
  end

  def process_messages(channel, params)
    Whatsapp::IncomingMessageBaileysService.new(inbox: channel.inbox, params: params).perform
  end
end
