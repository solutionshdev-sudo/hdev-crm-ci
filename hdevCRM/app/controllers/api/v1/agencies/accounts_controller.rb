class Api::V1::Agencies::AccountsController < Api::BaseController
  include EnsureAgencyAccess

  # Roda depois dos guards do EnsureAgencyAccess (incluído acima), então
  # @agency já está resolvida e autorizada.
  before_action :validate_client_account_limit, only: [:create]

  rescue_from CustomExceptions::Account::InvalidEmail,
              CustomExceptions::Account::UserExists,
              CustomExceptions::Account::UserErrors,
              with: :render_error_response

  def index
    accounts = @agency.accounts.order(id: :desc)
    render json: accounts.as_json(only: %i[id name status locale created_at])
  end

  def create
    user, account = AccountBuilder.new(
      account_name: permitted_params[:account_name],
      email: permitted_params[:email],
      user_full_name: permitted_params[:user_full_name],
      user_password: permitted_params[:password],
      confirmed: true,
      agency: @agency
    ).perform

    render json: {
      account: account.as_json(only: %i[id name status]),
      user: user.as_json(only: %i[id email name])
    }
  end

  private

  def validate_client_account_limit
    Plan::LimitEnforcer.new(agency: @agency).allow!(:client_account)
  end

  def permitted_params
    params.permit(:account_name, :email, :user_full_name, :password)
  end
end
