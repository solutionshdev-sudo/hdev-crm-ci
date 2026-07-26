# Baileys webhooks arrive already translated to the Meta Cloud API shape by
# the microservice, so the whole Cloud ingestion pipeline applies. Only media
# retrieval differs: files are fetched straight from baileys-service instead
# of the Graph API (the media id IS the cache key — no URL lookup round-trip).
class Whatsapp::IncomingMessageBaileysService < Whatsapp::IncomingMessageWhatsappCloudService
  private

  def download_attachment_file(attachment_payload)
    downloaded_file = Down.download(
      inbox.channel.media_url(attachment_payload[:id]),
      headers: inbox.channel.api_headers,
      max_size: 40 * 1024 * 1024
    )
    filename = attachment_payload[:filename]
    downloaded_file.define_singleton_method(:original_filename) { filename } if filename.present?
    downloaded_file
  end
end
