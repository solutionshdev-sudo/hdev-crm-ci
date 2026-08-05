# Provisions the baileys-service instance outside the create request, so a
# microservice outage can never block inbox creation. Failures surface via
# prompt_reauthorization! -> the dashboard shows the reconnect banner.
class Whatsapp::BaileysProvisionJob < ApplicationJob
  queue_as :default
  retry_on Whatsapp::BaileysClient::ApiError, Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout,
           wait: :polynomially_longer, attempts: 5

  def perform(channel_id)
    channel = Channel::Whatsapp.find_by(id: channel_id)
    return if channel.blank? || !channel.baileys?

    Whatsapp::BaileysSessionService.new(channel: channel).provision!
  rescue StandardError => e
    Rails.logger.error("[BAILEYS] provision failed channel=#{channel_id}: #{e.message}")
    channel&.prompt_reauthorization!
    raise
  end
end
