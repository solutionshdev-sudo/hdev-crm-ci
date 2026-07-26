# HTTP client for the baileys-service microservice (unofficial WhatsApp).
# The service lives on the internal compose network only; auth is a shared
# bearer key. All calls are short-lived except media download.
class Whatsapp::BaileysClient
  DEFAULT_TIMEOUT = 5

  class ApiError < StandardError; end

  def initialize
    @base_url = ENV.fetch('BAILEYS_URL', 'http://baileys:3025')
    @api_key = ENV.fetch('BAILEYS_API_KEY', nil)
  end

  def provision(channel)
    post("/instances", {
           id: channel.provider_config['instance_id'],
           phoneNumber: channel.phone_number,
           webhookUrl: webhook_url(channel),
           webhookSecret: channel.provider_config['webhook_secret'],
           proxyUrl: channel.provider_config['proxy_url'].presence,
           pairingMethod: channel.provider_config['pairing_method'].presence || 'qr'
         })
  end

  def status(instance_id)
    get("/instances/#{instance_id}")
  end

  def connect(instance_id, use_pairing_code: false)
    post("/instances/#{instance_id}/connect", { usePairingCode: use_pairing_code })
  end

  def logout(instance_id)
    post("/instances/#{instance_id}/logout", {})
  end

  def destroy(instance_id)
    response = HTTParty.delete("#{@base_url}/instances/#{instance_id}", headers: headers, timeout: DEFAULT_TIMEOUT)
    parse(response)
  end

  def send_message(instance_id, payload)
    post("/instances/#{instance_id}/messages", payload, timeout: 30)
  end

  def media_url(instance_id, media_id)
    "#{@base_url}/instances/#{instance_id}/media/#{media_id}"
  end

  def api_headers
    headers
  end

  private

  def webhook_url(channel)
    base = ENV.fetch('RAILS_INTERNAL_URL') { ENV.fetch('FRONTEND_URL') }
    "#{base}/webhooks/baileys/#{channel.provider_config['instance_id']}"
  end

  def get(path)
    parse(HTTParty.get("#{@base_url}#{path}", headers: headers, timeout: DEFAULT_TIMEOUT))
  end

  def post(path, body, timeout: DEFAULT_TIMEOUT)
    parse(HTTParty.post("#{@base_url}#{path}", headers: headers, body: body.to_json, timeout: timeout))
  end

  def parse(response)
    raise ApiError, "baileys-service #{response.code}: #{response.body.to_s.first(200)}" unless response.success?

    response.parsed_response
  end

  def headers
    { 'Authorization' => "Bearer #{@api_key}", 'Content-Type' => 'application/json' }
  end
end
