# Lifecycle glue between Channel::Whatsapp (provider baileys) and the
# baileys-service instance. Connection state lands in provider_config via
# update_column: update! would re-run validate_provider_config and fire
# after_update_commit hooks for what is effectively ephemeral state.
class Whatsapp::BaileysSessionService
  pattr_initialize [:channel!]

  def provision!
    client.provision(channel)
  end

  def connect!(use_pairing_code: false)
    client.connect(instance_id, use_pairing_code: use_pairing_code)
  end

  def logout!
    client.logout(instance_id)
    write_state('connection_state' => 'disconnected')
  end

  def status
    client.status(instance_id)
  end

  # Applies a `connection.update` webhook event to the channel.
  def sync_state!(value)
    updates = { 'connection_state' => value[:status].to_s }
    updates['connected_jid'] = value[:jid] if value[:jid].present?
    updates['last_disconnect_reason'] = value[:disconnect_reason] if value[:disconnect_reason].present?

    if value[:jid].present? && jid_mismatch?(value[:jid])
      Rails.logger.warn(
        "[BAILEYS] connected JID #{value[:jid]} does not match channel phone #{channel.phone_number} " \
        "(channel_id=#{channel.id})"
      )
    end

    write_state(updates)
  end

  private

  def client
    @client ||= Whatsapp::BaileysClient.new
  end

  def instance_id
    channel.provider_config['instance_id']
  end

  def jid_mismatch?(jid)
    jid_number = jid.to_s.split('@').first.to_s.split(':').first
    channel.phone_number.delete('+') != jid_number
  end

  def write_state(updates)
    # rubocop:disable Rails/SkipsModelValidations
    channel.update_column(:provider_config, channel.provider_config.merge(updates))
    # rubocop:enable Rails/SkipsModelValidations
  end
end
