# Mostly modeled after the intial implementation of the service based on 360 Dialog
# https://docs.360dialog.com/whatsapp-api/whatsapp-api/media
# https://developers.facebook.com/docs/whatsapp/api/media/
class Whatsapp::IncomingMessageBaseService
  include ::Whatsapp::IncomingMessageServiceHelpers
  include ::Whatsapp::IncomingMessageIdentifierHelper

  pattr_initialize [:inbox!, :params!, :outgoing_echo]

  def perform
    processed_params

    if processed_params.try(:[], :statuses).present?
      process_statuses
    elsif messages_data.present?
      process_messages
    end
  end

  # Returns messages array for both regular messages and echo events
  def messages_data
    @processed_params&.dig(:messages) || @processed_params&.dig(:message_echoes)
  end

  private

  # Guardas (tipo não suportado, dedupe de webhook, lock atômico e contato bloqueado/ausente)
  # e a montagem de ingest_message vivem em Whatsapp::IncomingMessageServiceHelpers —
  # extraído daqui pra manter process_messages abaixo do teto de complexidade
  # (Metrics/CyclomaticComplexity e PerceivedComplexity) sem estourar o ClassLength
  # desta classe (a concern tem folga; esta classe já estava perto do teto).
  def process_messages
    return if skip_incoming_message?
    return unless contact_ready_to_process?

    ingest_message
  end

  # opted_out fica fora da transaction: o job de nota de atividade só é enfileirado
  # depois do commit, pra não referenciar uma @conversation ainda não persistida.
  def ingest_message
    opted_out = false
    ActiveRecord::Base.transaction do
      set_conversation
      opted_out = detect_opt_out! unless outgoing_echo
      create_messages
    end
    create_opt_out_activity_message if opted_out
  end

  def process_statuses
    status = @processed_params[:statuses].first
    return unless find_message_by_source_id(status[:id])

    update_whatsapp_identifiers_from_status(status)
    update_message_with_status(@message, status)
  rescue ArgumentError => e
    Rails.logger.error "Error while processing whatsapp status update #{e.message}"
  end

  def update_message_with_status(message, status)
    message.status = status[:status]
    if status[:status] == 'failed' && status[:errors].present?
      error = status[:errors]&.first
      message.external_error = "#{error[:code]}: #{error[:title]}"
    end
    message.save!
  end

  def create_messages
    message = messages_data.first
    return create_unsupported_message(message) if message_type == 'unsupported'

    log_error(message) && return if error_webhook_event?(message)

    process_in_reply_to(message)

    message_type == 'contacts' ? create_contact_messages(message) : create_regular_message(message)
  end

  # WhatsApp delivers messages it cannot render (e.g. coexistence companion-device syncs that
  # fail with error 131060) as type: unsupported with no content. We still persist a placeholder
  # so the contact/conversation isn't created "headless" and agents know to check the WhatsApp app.
  def create_unsupported_message(message)
    log_error(message) if error_webhook_event?(message)
    process_in_reply_to(message)
    create_message(message, source_id: message[:id])
    @message.content = I18n.t('conversations.messages.whatsapp.unsupported_message')
    @message.content_attributes = @message.content_attributes.merge(is_unsupported: true)
    @message.save!
  end

  def create_contact_messages(message)
    message['contacts'].each_with_index do |contact, index|
      # Pass source_id from parent message since contact objects don't have :id
      create_message(contact, source_id: message[:id], content_attributes_source: message)
      # Vcards do mesmo webhook compartilham o timestamp do pai; +index µs desempata a
      # ordenação por created_at (o default_scope de Message não desempata por id).
      @message.created_at += index * 0.000001 if @message.created_at
      attach_contact(contact)
      @message.save!
    end
  end

  def create_regular_message(message)
    create_message(message, source_id: message[:id])
    attach_files
    attach_location if message_type == 'location'
    @message.save!
  end

  def set_contact
    if outgoing_echo
      set_contact_from_echo
    else
      set_contact_from_message
    end
  end

  def set_conversation
    # Scope reuse to the contact across all its contact_inboxes in this inbox: WhatsApp coexistence
    # gives one contact multiple source_ids (phone + BSUID), so reopen must not be limited to a single contact_inbox.
    conversations = @contact.conversations.where(inbox_id: @inbox.id)
    # if lock to single conversation is disabled, we will create a new conversation if previous conversation is resolved
    @conversation = if @inbox.lock_to_single_conversation
                      conversations.last
                    else
                      conversations.where.not(status: :resolved).last
                    end
    return if @conversation

    @conversation = ::Conversation.create!(conversation_params)
  end

  def attach_files
    return if %w[text button interactive location contacts].include?(message_type)

    attachment_payload = messages_data.first[message_type.to_sym]
    @message.content ||= attachment_payload[:caption]

    attachment_file = download_attachment_file(attachment_payload)
    return if attachment_file.blank?

    @message.attachments.new(
      account_id: @message.account_id,
      file_type: file_content_type(message_type),
      file: {
        io: attachment_file,
        filename: attachment_file.original_filename,
        content_type: attachment_file.content_type
      }
    )
  end

  def attach_location
    location = messages_data.first['location']
    location_name = (location['name'] ? "#{location['name']}, #{location['address']}" : '').first(255)
    @message.attachments.new(
      account_id: @message.account_id,
      file_type: file_content_type(message_type),
      coordinates_lat: location['latitude'],
      coordinates_long: location['longitude'],
      fallback_title: location_name,
      external_url: location['url']
    )
  end

  def create_message(message, source_id: nil, content_attributes_source: message)
    @message = @conversation.messages.build(
      content: message_content(message),
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: outgoing_echo ? :outgoing : :incoming,
      # Set status to :delivered for echo messages to prevent SendReplyJob from trying to send them
      status: outgoing_echo ? :delivered : :sent,
      sender: outgoing_echo ? nil : @contact,
      source_id: (source_id || message[:id]).to_s,
      # content_attributes_source é sempre a mensagem original do webhook (no contact
      # card, `message` aqui é o vcard, que não tem timestamp).
      created_at: message_timestamp(content_attributes_source),
      content_attributes: message_content_attributes(content_attributes_source)
    )
  end

  def message_content_attributes(message)
    content_attrs = outgoing_echo ? { external_echo: true } : {}
    content_attrs[:in_reply_to_external_id] = @in_reply_to_external_id if @in_reply_to_external_id.present?
    referral_content_attrs = referral_attributes(message)
    content_attrs[:referral] = referral_content_attrs if referral_content_attrs.present?
    content_attrs
  end

  def attach_contact(contact)
    phones = contact[:phones]
    phones = [{ phone: 'Phone number is not available' }] if phones.blank?

    name_info = contact['name'] || {}
    contact_meta = {
      firstName: name_info['first_name'],
      lastName: name_info['last_name']
    }.compact

    phones.each do |phone|
      @message.attachments.new(
        account_id: @message.account_id,
        file_type: file_content_type(message_type),
        fallback_title: phone[:phone].to_s,
        meta: contact_meta
      )
    end
  end

  def update_contact_with_profile_name(contact_params)
    profile_name = contact_params.dig(:profile, :name)
    return if profile_name.blank?
    return if @contact.name == profile_name

    # Only update if current name exactly matches the phone number or formatted phone number
    return unless contact_name_matches_phone_number?

    @contact.update!(name: profile_name)
  end

  def contact_name_matches_phone_number?
    message_phone_number = whatsapp_phone_number(messages_data.first[:from])
    return false if message_phone_number.blank?

    phone_number = "+#{message_phone_number}"
    formatted_phone_number = TelephoneNumber.parse(phone_number).international_number
    @contact.name == phone_number || @contact.name == formatted_phone_number
  end
end
