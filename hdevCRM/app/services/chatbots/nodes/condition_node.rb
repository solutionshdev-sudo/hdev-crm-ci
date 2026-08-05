class Chatbots::Nodes::ConditionNode < Chatbots::Nodes::BaseNode
  def execute
    handle = evaluate ? 'true' : 'false'
    [:continue, next_or_default(handle)]
  end

  private

  def evaluate
    rules = Array(data['rules'])
    return false if rules.blank?

    results = rules.map { |rule| evaluate_rule(rule) }
    data['mode'] == 'any' ? results.any? : results.all?
  end

  def evaluate_rule(rule)
    left = interpolate(rule['left'].to_s)
    right = interpolate(rule['right'].to_s)

    case rule['operator']
    when 'equals' then left.casecmp?(right)
    when 'not_equals' then !left.casecmp?(right)
    when 'contains' then left.downcase.include?(right.downcase)
    when 'not_contains' then !left.downcase.include?(right.downcase)
    when 'starts_with' then left.downcase.start_with?(right.downcase)
    when 'greater_than' then left.to_f > right.to_f
    when 'less_than' then left.to_f < right.to_f
    when 'is_present' then left.present?
    when 'is_blank' then left.blank?
    when 'matches_regex' then safe_regex_match?(left, right)
    else false
    end
  end

  # Regex vem do autor do fluxo — limitar tamanho e tratar erro de sintaxe.
  def safe_regex_match?(value, pattern)
    return false if pattern.blank? || pattern.length > 200

    Regexp.new(pattern, Regexp::IGNORECASE).match?(value)
  rescue RegexpError
    false
  end
end
