class Api::V1::Accounts::BaseController < Api::BaseController
  include SwitchLocale
  include EnsureCurrentAccountHelper
  before_action :current_account
  before_action :validate_token_api_access, if: :authenticate_by_access_token?
  around_action :switch_locale_using_account_locale

  private

  def validate_token_api_access
    return if Current.account.api_and_webhooks_enabled?

    render json: { error: I18n.t('errors.api.common.api_access_disabled') }, status: :forbidden
  end
end
