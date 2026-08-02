# Lifecycle glue between Channel::Whatsapp (provider baileys) and the
# baileys-service instance. Connection state lands in provider_config via
# update_column: update! would re-run validate_provider_config and fire
# after_update_commit hooks for what is effectively ephemeral state.
class Whatsapp::BaileysSessionService
  include Events::Types

  # Sinaliza pro painel que a instância não existe no microserviço: a UI mostra
  # "sessão parada" e o botão de QR resolve, em vez de erro de serviço fora do ar.
  NOT_PROVISIONED = 'not_provisioned'.freeze

  pattr_initialize [:channel!]

  def provision!
    client.provision(channel)
  end

  # Provisiona antes de conectar: provisionInstance é idempotente no microserviço,
  # então isso recria a instância que sumiu num restart sem volume (ou cujo
  # BaileysProvisionJob falhou) em vez de devolver 404 sem saída pelo painel.
  def connect!(use_pairing_code: false)
    provision!
    client.connect(instance_id, use_pairing_code: use_pairing_code)
  end

  def logout!
    client.logout(instance_id)
    write_state('connection_state' => 'disconnected')
  rescue Whatsapp::BaileysClient::NotFoundError
    write_state('connection_state' => 'disconnected')
  end

  def status
    sync_status(client.status(instance_id))
  rescue Whatsapp::BaileysClient::NotFoundError
    sync_status({ 'status' => 'disconnected', 'lastError' => NOT_PROVISIONED })
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

  # O polling da aba Conexão é a leitura de estado mais frequente que existe; sem
  # persistir aqui, o selo da lista de inboxes e o banner da caixa de resposta
  # ficam no último valor que o webhook trouxe — verde para sempre numa inbox
  # cuja instância morreu. Só escreve quando muda: são até 20 polls por minuto.
  def sync_status(value)
    state = value['status'].to_s
    write_state('connection_state' => state) if state.present? && state != channel.provider_config['connection_state']

    value
  end

  def jid_mismatch?(jid)
    jid_number = jid.to_s.split('@').first.to_s.split(':').first
    channel.phone_number.delete('+') != jid_number
  end

  # Carimba a hora sempre que o estado muda: é o que o painel mostra como
  # "última atualização" do selo de conexão.
  def write_state(updates)
    previous_state = channel.provider_config['connection_state']
    previous_jid = channel.provider_config['connected_jid']
    updates = updates.merge('connection_state_updated_at' => Time.current.iso8601)
    updates['paired_at'] = Time.current.iso8601 if newly_paired?(updates, previous_jid)
    # rubocop:disable Rails/SkipsModelValidations
    channel.update_column(:provider_config, channel.provider_config.merge(updates))
    # rubocop:enable Rails/SkipsModelValidations

    dispatch_connection_changed_event(updates['connection_state'], previous_state)
  end

  # Primeira transição pra "open" com um connected_jid novo = pareamento novo
  # (ou re-pareamento com número diferente) — zera o relógio do warm-up do
  # Messaging::SendGateService. Reconectar com o MESMO jid (drop de rede,
  # restart do container baileys) não reseta nada.
  def newly_paired?(updates, previous_jid)
    updates['connection_state'] == 'open' && updates['connected_jid'].present? && updates['connected_jid'] != previous_jid
  end

  # update_column pula os callbacks do model, então o dispatch tem que ser
  # explícito aqui — e só quando o estado de fato muda (o polling da aba
  # Conexão chama isso até 20x por minuto).
  def dispatch_connection_changed_event(connection_state, previous_state)
    return if connection_state.blank? || connection_state == previous_state

    Rails.configuration.dispatcher.dispatch(WHATSAPP_CONNECTION_CHANGED, Time.zone.now, inbox: channel.inbox,
                                                                                        connection_state: connection_state,
                                                                                        previous_state: previous_state)
  end
end
