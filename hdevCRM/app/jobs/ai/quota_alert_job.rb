# Disparado pelo after_create_commit de AiUsageEvent. Burro de propósito:
# cooldown Redis, limiares e mailer continuam em
# Ai::QuotaService#check_thresholds!, testável sem job no meio.
class Ai::QuotaAlertJob < ApplicationJob
  queue_as :default

  def perform(account_id)
    account = Account.find_by(id: account_id)
    return if account.blank?

    Ai::QuotaService.new(account: account).check_thresholds!
  end
end
