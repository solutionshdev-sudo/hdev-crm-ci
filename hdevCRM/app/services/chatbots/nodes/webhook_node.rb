class Chatbots::Nodes::WebhookNode < Chatbots::Nodes::BaseNode
  TIMEOUT = 10

  def execute
    response = request
    if response&.success?
      store_response(response)
      [:continue, next_or_default('out')]
    else
      session.log_event(:failed, node: node, data: { http_status: response&.code })
      [:continue, next_id('error') || next_or_default('out')]
    end
  rescue StandardError => e
    session.log_event(:failed, node: node, data: { error: e.message.first(200) })
    [:continue, next_id('error') || next_or_default('out')]
  end

  private

  def request
    url = interpolate(data['url'].to_s)
    return if url.blank? || !url.start_with?('http')

    headers = (data['headers'] || {}).transform_values { |value| interpolate(value.to_s) }
    if data['method'].to_s.casecmp?('get')
      HTTParty.get(url, headers: headers, timeout: TIMEOUT)
    else
      body = interpolate((data['body_template'] || {}).to_json)
      HTTParty.post(url, headers: { 'Content-Type' => 'application/json' }.merge(headers), body: body, timeout: TIMEOUT)
    end
  end

  def store_response(response)
    key = data['save_as'].presence
    return unless key

    session.variables[key] = response.body.to_s.first(2_000)
  end
end
