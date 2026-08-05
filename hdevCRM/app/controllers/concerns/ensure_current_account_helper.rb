module EnsureCurrentAccountHelper
  private

  def current_account
    @current_account ||= ensure_current_account
    Current.account = @current_account
  end

  def ensure_current_account
    account = Account.find(params[:account_id])
    return if render_suspension_error(account)

    if current_user
      account_accessible_for_user?(account)
    elsif @resource.is_a?(AgentBot)
      account_accessible_for_bot?(account)
    else
      render_unauthorized(I18n.t('errors.account.not_authorized'))
    end
    account
  end

  # Conta suspensa bloqueia com a mensagem antiga. Agência suspensa bloqueia
  # com a mensagem nova — mas pending_payment da agência NÃO propaga: a conta
  # filha aguardando o 1º pagamento não deve morrer por causa disso. Só
  # suspended? bloqueia. Devolve truthy quando já renderizou a resposta.
  def render_suspension_error(account)
    unless account.active?
      render_unauthorized(I18n.t('errors.api.account.suspended'))
      return true
    end

    if account.agency&.suspended?
      render_unauthorized(I18n.t('errors.api.account.agency_suspended'))
      return true
    end

    false
  end

  def account_accessible_for_user?(account)
    @current_account_user = account.account_users.find_by(user_id: current_user.id)
    Current.account_user = @current_account_user
    render_unauthorized(I18n.t('errors.account.not_authorized')) unless @current_account_user
  end

  def account_accessible_for_bot?(account)
    return if @resource.account_id == account.id
    return if @resource.agent_bot_inboxes.find_by(account_id: account.id)

    render_unauthorized(I18n.t('errors.api.account.bot_not_authorized'))
  end
end
