class Api::V1::Accounts::AiUsagesController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  def show
    render json: Ai::QuotaService.new(account: Current.account).account_summary
  end
end
