class ContentAttributeValidator < ActiveModel::Validator
  ALLOWED_SELECT_ITEM_KEYS = [:title, :value].freeze
  ALLOWED_CARD_ITEM_KEYS = [:title, :description, :media_url, :actions].freeze
  ALLOWED_CARD_ITEM_ACTION_KEYS = [:text, :type, :payload, :uri].freeze
  ALLOWED_FORM_ITEM_KEYS = [:type, :placeholder, :label, :name, :options, :default, :required, :pattern, :title, :pattern_error].freeze
  ALLOWED_ARTICLE_KEYS = [:title, :description, :link].freeze

  def validate(record)
    case record.content_type
    when 'input_select'
      validate_items!(record)
      validate_item_attributes!(record, ALLOWED_SELECT_ITEM_KEYS)
    when 'cards'
      validate_items!(record)
      validate_item_attributes!(record, ALLOWED_CARD_ITEM_KEYS)
      validate_item_actions!(record)
    when 'form'
      validate_items!(record)
      validate_item_attributes!(record, ALLOWED_FORM_ITEM_KEYS)
    when 'article'
      validate_items!(record)
      validate_item_attributes!(record, ALLOWED_ARTICLE_KEYS)
    end
  end

  private

  def validate_items!(record)
    record.errors.add(:content_attributes, I18n.t('errors.models.content_attributes.items_required')) if record.items.blank?
    return if record.items.reject { |item| item.is_a?(Hash) }.blank?

    record.errors.add(:content_attributes, I18n.t('errors.models.content_attributes.items_type'))
  end

  def validate_item_attributes!(record, valid_keys)
    item_keys = record.items.collect(&:keys).flatten.filter_map(&:to_sym)
    invalid_keys = item_keys - valid_keys
    return if invalid_keys.blank?

    record.errors.add(:content_attributes, I18n.t('errors.models.content_attributes.invalid_item_keys', invalid_keys: invalid_keys))
  end

  def validate_item_actions!(record)
    if record.items.select { |item| item[:actions].blank? }.present?
      record.errors.add(:content_attributes, I18n.t('errors.models.content_attributes.missing_item_actions')) && return
    end

    validate_item_action_attributes!(record)
  end

  def validate_item_action_attributes!(record)
    item_action_keys = record.items.collect { |item| item[:actions].collect(&:keys) }
    invalid_keys = item_action_keys.flatten.compact.map(&:to_sym) - ALLOWED_CARD_ITEM_ACTION_KEYS
    return if invalid_keys.blank?

    record.errors.add(:content_attributes, I18n.t('errors.models.content_attributes.invalid_action_keys', invalid_keys: invalid_keys))
  end
end
