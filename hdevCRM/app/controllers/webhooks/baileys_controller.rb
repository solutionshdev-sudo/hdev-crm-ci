# Receives events from baileys-service. Dedicated route (not the Meta one:
# Webhooks::WhatsappController skips signature checks for non-cloud providers,
# which would leave this endpoint wide open). Auth is HMAC-SHA256 of the RAW
# body with the per-instance webhook_secret.
class Webhooks::BaileysController < ActionController::API
  before_action :verify_signature!

  def process_payload
    Webhooks::BaileysEventsJob.perform_later(
      params.to_unsafe_hash.except(:controller, :action, :baileys),
      params[:instance_id]
    )
    head :ok
  end

  private

  def verify_signature!
    channel = channel_by_instance_id
    return head :unauthorized if channel.blank?

    secret = channel.provider_config['webhook_secret']
    return head :unauthorized if secret.blank?

    signature = request.headers['X-Baileys-Signature'].to_s.delete_prefix('sha256=')
    expected = OpenSSL::HMAC.hexdigest('sha256', secret, request.raw_post)
    return if ActiveSupport::SecurityUtils.secure_compare(expected, signature)

    head :unauthorized
  end

  def channel_by_instance_id
    Channel::Whatsapp
      .where(provider: 'baileys')
      .find_by("provider_config ->> 'instance_id' = ?", params[:instance_id])
  end
end
