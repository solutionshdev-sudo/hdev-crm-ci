# {{...}} interpolation with an allowlist resolver — never Liquid/ERB, which
# would be an injection surface for user-authored flows.
class Chatbots::Interpolator
  PATTERN = /\{\{\s*([\w.]+)\s*\}\}/

  def initialize(session)
    @session = session
    @conversation = session.conversation
    @contact = session.contact || @conversation.contact
  end

  def interpolate(text)
    return text if text.blank?

    text.gsub(PATTERN) do
      value = resolve(Regexp.last_match(1))
      @session.log_event(:failed, data: { unknown_variable: Regexp.last_match(1) }) if value.nil?
      value.to_s
    end
  end

  private

  def resolve(path)
    case path
    when 'contact.name' then @contact&.name
    when 'contact.email' then @contact&.email
    when 'contact.phone_number' then @contact&.phone_number
    when 'conversation.id' then @conversation.display_id
    when 'inbox.name' then @conversation.inbox.name
    when 'account.name' then @conversation.account.name
    when 'now' then I18n.l(Time.current, format: :short)
    else
      resolve_nested(path)
    end
  end

  def resolve_nested(path)
    if path.start_with?('vars.')
      @session.variables[path.delete_prefix('vars.')]
    elsif path.start_with?('contact.custom_attributes.')
      @contact&.custom_attributes&.dig(path.delete_prefix('contact.custom_attributes.'))
    end
  end
end
