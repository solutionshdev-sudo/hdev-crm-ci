module Ai
  # Monthly AI token quotas, enforced at two levels:
  # - per account: `account.custom_attributes['ai_monthly_tokens']`
  #   (custom_attributes because `limits` is schema-locked when enterprise/ is loaded)
  # - per agency:  `agency.settings['ai_monthly_tokens']` (sum of all its accounts)
  # A missing/blank limit means unlimited.
  class QuotaService
    pattr_initialize [:account!]

    def exceeded?
      account_exceeded? || agency_exceeded?
    end

    def account_exceeded?
      account_limit.present? && account_usage >= account_limit
    end

    def agency_exceeded?
      agency_limit.present? && agency_usage >= agency_limit
    end

    def account_limit
      account.custom_attributes&.dig('ai_monthly_tokens')&.to_i
    end

    def agency_limit
      agency&.settings&.dig('ai_monthly_tokens')&.to_i
    end

    def account_usage
      AiUsageEvent.where(account_id: account.id).in_period(current_period).sum(:total_tokens)
    end

    def agency_usage
      return 0 if agency.blank?

      AiUsageEvent.where(agency_id: agency.id).in_period(current_period).sum(:total_tokens)
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
  end
end
