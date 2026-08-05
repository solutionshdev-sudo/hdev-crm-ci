# Matches a customer's reply against a question node's options. WhatsApp
# button replies come back as the button TITLE (not id) — see
# IncomingMessageServiceHelpers#message_content — so the session context keeps
# an option_map of title => option id.
class Chatbots::AnswerMatcher
  def initialize(node_data, session, message)
    @options = Array(node_data['options'])
    @session = session
    @message = message
  end

  # Retorna o id da opção casada, ou nil.
  def match
    return if @options.blank?

    from_submitted_values || from_option_map || from_digit || from_title_or_value
  end

  private

  def content
    @message.content.to_s.strip
  end

  # Payload de interactive (button_reply/list_reply) chega em submitted_values.
  def from_submitted_values
    submitted = @message.content_attributes&.dig('submitted_values')
    return if submitted.blank?

    value = submitted.first&.dig('value') || submitted.first&.dig('id')
    @options.find { |option| option['id'] == value || option['value'] == value }&.dig('id')
  end

  def from_option_map
    map = @session.context['option_map'] || {}
    map[content.downcase]
  end

  # Brasileiro responde "1" — casa com a posição da opção.
  def from_digit
    return unless content.match?(/\A\d{1,2}\z/)

    @options[content.to_i - 1]&.dig('id')
  end

  def from_title_or_value
    normalized = content.downcase
    @options.find do |option|
      option['title'].to_s.downcase == normalized || option['value'].to_s.downcase == normalized
    end&.dig('id')
  end
end
