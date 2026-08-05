class Chatbots::Nodes::CollectNode < Chatbots::Nodes::BaseNode
  DEFAULT_MAX_RETRIES = 2

  VALIDATORS = {
    'email' => ->(value) { value.match?(URI::MailTo::EMAIL_REGEXP) },
    'phone' => ->(value) { value.gsub(/\D/, '').length.between?(8, 15) },
    'number' => ->(value) { value.match?(/\A-?\d+([.,]\d+)?\z/) },
    'date' => lambda { |value|
      begin
        Date.parse(value)
        true
      rescue Date::Error
        false
      end
    },
    'cpf' => ->(value) { value.gsub(/\D/, '').length == 11 },
    'cnpj' => ->(value) { value.gsub(/\D/, '').length == 14 }
  }.freeze

  def execute
    session.context['retries'] = 0
    send_text(data['content'])
    [:wait, :waiting_input, node_timeout]
  end

  def handle_input(message)
    content = message.content.to_s.strip
    session.log_event(:input_received, node: node, data: { content: content.first(120) })

    unless valid?(content)
      retries = session.context['retries'].to_i + 1
      max_retries = (data['max_retries'] || DEFAULT_MAX_RETRIES).to_i
      if retries < max_retries
        session.context['retries'] = retries
        send_text(data['invalid_message'].presence || I18n.t('chatbots.invalid_answer'))
        return [:wait, :waiting_input, node_timeout]
      end
      fallback = next_id('fallback')
      return [:continue, fallback] if fallback
      # sem fallback: aceita o valor cru e segue — travar o fluxo é pior
    end

    store(content)
    [:continue, next_or_default('out')]
  end

  private

  def valid?(content)
    validator = VALIDATORS[data['validation']]
    if data['validation'] == 'regex'
      pattern = data['regex'].to_s
      return content.match?(Regexp.new(pattern)) if pattern.present? && pattern.length <= 200

      true
    elsif validator
      validator.call(content)
    else
      true
    end
  rescue RegexpError
    true
  end

  def store(content)
    key = data['save_as'].presence
    session.variables[key] = content if key
    map_to_contact(content)
  end

  def map_to_contact(content)
    target = data['map_to'].to_s
    contact = session.contact || conversation.contact
    return if target.blank? || contact.blank?

    case target
    when 'contact.name' then contact.update(name: content)
    when 'contact.email' then contact.update(email: content)
    when 'contact.phone_number' then contact.update(phone_number: content)
    else
      if target.start_with?('contact.custom_attributes.')
        key = target.delete_prefix('contact.custom_attributes.')
        contact.update(custom_attributes: contact.custom_attributes.merge(key => content))
      end
    end
  rescue ActiveRecord::RecordInvalid
    # valor não passou nas validações do contato (ex.: email duplicado) — fica só em vars
  end
end
