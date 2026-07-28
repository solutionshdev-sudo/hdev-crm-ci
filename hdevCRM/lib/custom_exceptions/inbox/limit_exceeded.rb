# frozen_string_literal: true

class CustomExceptions::Inbox::LimitExceeded < CustomExceptions::Base
  def message
    I18n.t('errors.api.inbox.limit_exceeded')
  end

  def to_hash
    { error: message }
  end

  def http_status
    :payment_required
  end
end
