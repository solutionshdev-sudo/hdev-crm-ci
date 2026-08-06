module Ai
  # Monthly AI token quotas, enforced at two levels:
  # - per account, per agency (sum of all its accounts)
  # O limite efetivo de cada dono é: o plano contratado (`plan.ai_monthly_tokens`,
  # quando a subscription concede acesso) somado a `ai_extra_tokens`; sem
  # subscription vigente, cai pro fallback legado (`custom_attributes` na
  # conta / `settings` na agência -- `limits` é schema-locked quando
  # enterprise/ é carregado). Extra só soma sobre limite finito: se a base é
  # nula (plano sem teto OU fallback ausente), o resultado continua ilimitado
  # -- não faz sentido "estender" um teto que não existe.
  class QuotaService
    pattr_initialize [:account!]

    QUOTA_ALERT_COOLDOWN = 24.hours.to_i

    def exceeded?
      account_exceeded? || agency_exceeded?
    end

    def account_exceeded?
      account_limit.present? && account_usage >= account_limit
    end

    def agency_exceeded?
      agency_limit.present? && agency_usage >= agency_limit
    end

    # F6: a fatia que a agência alocou (plan_allocations) vence a cadeia
    # inteira quando a chave existe — null na alocação = ilimitado explícito.
    # O extra segue a regra do effective_limit: só soma sobre base finita.
    def account_limit
      return allocation_limit if account.plan_allocations&.key?('ai_monthly_tokens')

      effective_limit(account, account_fallback_limit)
    end

    def agency_limit
      return nil if agency.blank?

      effective_limit(agency, agency_fallback_limit)
    end

    # Chamado pelo Ai::QuotaAlertJob (enfileirado no after_create_commit de
    # AiUsageEvent — F7.5 tirou o mailer da request). Nunca pode derrubar o
    # fluxo de IA: erro de Redis/mailer vira só log. Cooldown de 24h por
    # limiar (80/100) em Redis evita floodar o admin a cada iteração do
    # tool loop.
    def check_thresholds!
      limit = account_limit
      return if limit.blank?

      percent = (account_usage.to_f / limit) * 100
      if percent >= 100
        alert_threshold!(100)
      elsif percent >= 80
        alert_threshold!(80)
      end
    rescue StandardError => e
      Rails.logger.error("Ai::QuotaService#check_thresholds! account_id=#{account.id}: #{e.message}")
    end

    # F7.5: leitura O(1) no contador (ai_usage_counters) em vez de
    # SUM(total_tokens) — o ToolLoop consulta exceeded? a cada iteração.
    def account_usage
      AiUsageCounter.current_for(account)&.tokens || 0
    end

    def agency_usage
      return 0 if agency.blank?

      AiUsageCounter.current_for(agency)&.tokens || 0
    end

    def account_summary
      {
        period_start: current_period.begin,
        monthly_limit: account_limit,
        tokens_used: account_usage,
        exceeded: exceeded?,
        usage: AiUsageEvent.where(account_id: account.id).in_period(current_period).summary
      }
    end

    def current_period
      Time.zone.now.beginning_of_month..Time.zone.now
    end

    private

    def agency
      account.agency
    end

    def effective_limit(owner, fallback)
      subscription = owner.subscription
      base = subscription&.grants_plan? ? subscription.plan.ai_monthly_tokens : fallback
      return nil if base.blank?

      base.to_i + owner.ai_extra_tokens.to_i
    end

    def allocation_limit
      base = account.plan_allocations['ai_monthly_tokens']
      return nil if base.nil?

      base.to_i + account.ai_extra_tokens.to_i
    end

    def account_fallback_limit
      account.custom_attributes&.dig('ai_monthly_tokens')&.to_i
    end

    def agency_fallback_limit
      agency&.settings&.dig('ai_monthly_tokens')&.to_i
    end

    def alert_threshold!(threshold)
      key = format(Redis::RedisKeys::AI_QUOTA_ALERT_KEY, account_id: account.id, threshold: threshold)
      return unless Redis::Alfred.set(key, true, nx: true, ex: QUOTA_ALERT_COOLDOWN)

      deliver_quota_mail(threshold)
    end

    def deliver_quota_mail(threshold)
      mailer = AdministratorNotifications::AccountNotificationMailer.with(account: account)
      if threshold == 100
        mailer.ai_quota_exhausted(threshold).deliver_later
      else
        mailer.ai_quota_threshold(threshold).deliver_later
      end
    end
  end
end
