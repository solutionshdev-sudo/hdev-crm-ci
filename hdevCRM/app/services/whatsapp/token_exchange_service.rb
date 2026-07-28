class Whatsapp::TokenExchangeService
  def initialize(code)
    @code = code
    @api_client = Whatsapp::FacebookApiClient.new
  end

  def perform
    validate_code!
    exchange_token
  end

  private

  def validate_code!
    raise ArgumentError, I18n.t('errors.api.whatsapp.authorization_code_required') if @code.blank?
  end

  def exchange_token
    response = @api_client.exchange_code_for_token(@code)
    access_token = response['access_token']

    raise I18n.t('errors.api.whatsapp.no_access_token', response: response) if access_token.blank?

    access_token
  end
end
