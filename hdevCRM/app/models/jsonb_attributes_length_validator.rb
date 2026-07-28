class JsonbAttributesLengthValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.empty?

    @attribute = attribute
    @record = record

    value.each do |key, attribute_value|
      validate_keys(key, attribute_value)
    end
  end

  def validate_keys(key, attribute_value)
    case attribute_value.class.name
    when 'String'
      @record.errors.add @attribute, I18n.t('errors.models.jsonb_attributes.key_length', key: key) if attribute_value.length > 1500
    when 'Integer'
      @record.errors.add @attribute, I18n.t('errors.models.jsonb_attributes.key_value', key: key) if attribute_value > 9_999_999_999
    end
  end
end
