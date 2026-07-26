# Unofficial WhatsApp provider backed by the baileys-service microservice.
# The HTTP contract mirrors the Meta Cloud API shapes, so this class stays a
# thin translation of Message -> Cloud send payload.
#
# validate_provider_config? is LOCAL-ONLY on purpose: the model runs it on
# every create/update, and pinging the microservice there would make any
# baileys-service outage block editing every WhatsApp inbox. Remote health is
# handled by Whatsapp::BaileysProvisionJob.
class Whatsapp::Providers::WhatsappBaileysService < Whatsapp::Providers::BaseService
  def send_message(phone_number, message)
    payload =
      if message.attachments.present?
        attachment_payload(phone_number, message)
      elsif message.content_type == 'input_select'
        interactive_payload(phone_number, message)
      else
        { to: phone_number, type: 'text', text: { body: message.outgoing_content } }
      end

    response = client.send_message(instance_id, payload)
    response['messages']&.first&.dig('id')
  rescue Whatsapp::BaileysClient::ApiError => e
    handle_send_error(message, e)
  end

  # No template registry on the unofficial API: render the template body
  # locally and send it as a plain session message (no 24h window applies).
  def send_template(phone_number, template_info, message = nil)
    body = template_text(template_info)
    return if body.blank?

    response = client.send_message(instance_id, { to: phone_number, type: 'text', text: { body: body } })
    response['messages']&.first&.dig('id')
  rescue Whatsapp::BaileysClient::ApiError => e
    handle_send_error(message, e)
  end

  def sync_templates
    # No-op: unofficial API has no template catalog. Marking keeps the
    # scheduler from treating the channel as perpetually stale.
    whatsapp_channel.mark_message_templates_updated
  end

  def validate_provider_config?
    config = whatsapp_channel.provider_config
    return false if config['instance_id'].blank? || config['webhook_secret'].blank?

    valid_proxy_url?(config['proxy_url'])
  end

  def api_headers
    client.api_headers
  end

  def media_url(media_id)
    client.media_url(instance_id, media_id)
  end

  def error_message(_response = nil)
    @last_error
  end

  private

  def client
    @client ||= Whatsapp::BaileysClient.new
  end

  def instance_id
    whatsapp_channel.provider_config['instance_id']
  end

  def valid_proxy_url?(proxy_url)
    return true if proxy_url.blank?

    uri = URI.parse(proxy_url)
    %w[http https socks socks5 socks4].include?(uri.scheme) && uri.host.present?
  rescue URI::InvalidURIError
    false
  end

  def attachment_payload(phone_number, message)
    attachment = message.attachments.first
    type = %w[image audio video].include?(attachment.file_type) ? attachment.file_type : 'document'
    content = { link: attachment.download_url }
    content[:caption] = message.outgoing_content if %w[image video document].include?(type)
    if type == 'document'
      content[:filename] = attachment.file.filename.to_s
      content[:mime_type] = attachment.file.content_type
    end
    { to: phone_number, type: type, type.to_sym => content }
  end

  def interactive_payload(phone_number, message)
    items = message.content_attributes['items'] || []
    {
      to: phone_number,
      type: 'interactive',
      interactive: {
        body: { text: message.outgoing_content },
        action: { buttons: items.map { |item| { reply: { id: item['value'], title: item['title'] } } } }
      }
    }
  end

  def template_text(template_info)
    processed = template_info&.dig(:processed_params) || {}
    body = template_info&.dig(:body).presence || processed['body_text']
    body.presence || processed.values.join(' ')
  end

  def handle_send_error(message, error)
    @last_error = error.message
    Rails.logger.error("[BAILEYS] send failed channel=#{whatsapp_channel.id}: #{error.message}")
    return if message.blank?

    message.external_error = @last_error
    message.status = :failed
    message.save!
    nil
  end
end
