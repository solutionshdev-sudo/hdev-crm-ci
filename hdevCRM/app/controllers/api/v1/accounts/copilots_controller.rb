class Api::V1::Accounts::CopilotsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  rescue_from Ai::QuotaExceededError do
    render json: { error: I18n.t('errors.api.copilot.quota_exceeded') }, status: :too_many_requests
  end

  # Erro previsível de ferramenta (validação, id inexistente) na hora de
  # aplicar: no preview ele volta pro modelo, aqui volta pro admin.
  rescue_from Ai::ToolError, Ai::CopilotService::UnknownChangeError do |error|
    render json: { error: error.message }, status: :unprocessable_entity
  end

  # Propõe: roda o modelo com as ferramentas em preview. Nada é gravado.
  def create
    render json: copilot.propose(permitted_messages)
  end

  # Aplica: só aqui grava, e só o que o admin devolveu confirmado.
  def apply
    render json: { results: copilot.apply(permitted_changes) }
  end

  private

  def copilot
    Ai::CopilotService.new(account: Current.account, user: current_user)
  end

  def permitted_messages
    params.permit(messages: [:role, :content])[:messages]
  end

  # `input: {}` libera o hash aninhado da ferramenta. É seguro porque a mesma
  # whitelist de tools valida tudo de novo na aplicação, e o escopo é o
  # Current.account — o admin não alcança nada que já não alcance pela API.
  def permitted_changes
    params.permit(changes: [:name, { input: {} }])[:changes]
  end
end
