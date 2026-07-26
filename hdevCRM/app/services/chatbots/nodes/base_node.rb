class Chatbots::Nodes::BaseNode
  attr_reader :session, :node

  def initialize(session, node)
    @session = session
    @node = node
  end

  # Retorno padrão: [:continue, next_node_id] | [:wait, status, expires_at] | [:halt, status]
  def execute
    raise NotImplementedError
  end

  # Só nós de espera implementam.
  def handle_input(_message)
    raise NotImplementedError
  end

  private

  def data
    node['data'] || {}
  end

  def chatbot
    session.chatbot
  end

  def conversation
    session.conversation
  end

  def interpolate(text)
    Chatbots::Interpolator.new(session).interpolate(text)
  end

  def next_id(handle = nil)
    chatbot.next_node_id(node['id'], handle)
  end

  # Aresta específica com fallback pra saída única (Vue Flow omite o handle
  # quando o nó só tem uma saída).
  def next_or_default(handle)
    next_id(handle) || next_id
  end

  def send_text(content, extra_attributes = {})
    return if content.blank?

    params = {
      content: interpolate(content),
      private: false,
      content_attributes: { chatbot_id: chatbot.id, node_id: node['id'] }.merge(extra_attributes)
    }
    Messages::MessageBuilder.new(nil, conversation, params).perform
  end

  def send_question(content, options)
    params = {
      content: interpolate(content),
      content_type: 'input_select',
      private: false,
      content_attributes: {
        items: options.map { |option| { 'title' => option['title'], 'value' => option['id'] } },
        chatbot_id: chatbot.id,
        node_id: node['id']
      }
    }
    Messages::MessageBuilder.new(nil, conversation, params).perform
  end

  def default_timeout
    minutes = chatbot.settings['timeout_minutes'].to_i
    (minutes.positive? ? minutes.minutes : 24.hours).from_now
  end

  def node_timeout
    seconds = data['timeout_seconds'].to_i
    seconds.positive? ? seconds.seconds.from_now : default_timeout
  end
end
