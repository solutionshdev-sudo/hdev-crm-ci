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

  # Sempre 401 (nunca 404): baileys-service só trata 401 como terminal — outro
  # status queimaria as 5 tentativas de retry à toa. O motivo fica no log.
  def verify_signature!
    channel = channel_by_instance_id
    if channel.blank?
      Rails.logger.warn("[BAILEYS] webhook 401: no channel for instance=#{params[:instance_id]}")
      return head :unauthorized
    end

    secret = channel.provider_config['webhook_secret']
    if secret.blank?
      Rails.logger.warn("[BAILEYS] webhook 401: channel missing webhook_secret instance=#{params[:instance_id]}")
      return head :unauthorized
    end

    signature = request.headers['X-Baileys-Signature'].to_s.delete_prefix('sha256=')
    expected = OpenSSL::HMAC.hexdigest('sha256', secret, request.raw_post)
    return if ActiveSupport::SecurityUtils.secure_compare(expected, signature)

    Rails.logger.warn("[BAILEYS] webhook 401: invalid signature instance=#{params[:instance_id]}")
    head :unauthorized
  end

  def channel_by_instance_id
    Channel::Whatsapp
      .where(provider: 'baileys')
      .find_by("provider_config ->> 'instance_id' = ?", params[:instance_id])
  end
end
