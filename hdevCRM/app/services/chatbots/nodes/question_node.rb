class Chatbots::Nodes::QuestionNode < Chatbots::Nodes::BaseNode
  DEFAULT_MAX_RETRIES = 2

  def execute
    options = Array(data['options'])
    if data['input_type'] == 'free_text' || options.blank?
      send_text(data['content'])
    else
      send_question(data['content'], options)
    end
    remember_option_map(options)
    [:wait, :waiting_input, node_timeout]
  end

  def handle_input(message)
    session.log_event(:input_received, node: node, data: { content: message.content&.first(120) })

    if data['input_type'] == 'free_text' || Array(data['options']).blank?
      save_answer(message.content)
      return [:continue, next_or_default('out')]
    end

    option_id = Chatbots::AnswerMatcher.new(data, session, message).match
    if option_id
      save_answer(message.content)
      return [:continue, next_or_default(option_id)]
    end

    retries = session.context['retries'].to_i + 1
    max_retries = (data['max_retries'] || DEFAULT_MAX_RETRIES).to_i
    if retries >= max_retries
      session.context['retries'] = 0
      fallback = next_id('fallback')
      return [:continue, fallback] if fallback

      # sem fallback: não abandonar o cliente — devolve pra fila humana
      conversation.bot_handoff!
      return [:halt, :aborted]
    end

    session.context['retries'] = retries
    send_text(data['invalid_message'].presence || I18n.t('chatbots.invalid_option'))
    [:wait, :waiting_input, node_timeout]
  end

  private

  def remember_option_map(options)
    session.context['retries'] = 0
    session.context['option_map'] = options.each_with_object({}) do |option, map|
      map[option['title'].to_s.downcase] = option['id']
    end
  end

  def save_answer(content)
    key = data['save_as'].presence
    session.variables[key] = content if key
  end
end
