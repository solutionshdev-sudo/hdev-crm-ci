class Api::V1::Agencies::AiUsagesController < Api::BaseController
  include EnsureAgencyAccess

  def show
    period = Time.zone.now.beginning_of_month..Time.zone.now
    events = AiUsageEvent.where(agency_id: @agency.id).in_period(period)

    render json: {
      period_start: period.begin,
      monthly_limit: @agency.settings&.dig('ai_monthly_tokens')&.to_i,
      summary: events.summary,
      per_account: per_account_usage(events)
    }
  end

  private

  def per_account_usage(events)
    totals = events.group(:account_id).sum(:total_tokens)
    costs = events.group(:account_id).sum(:cost)
    names = Account.where(id: totals.keys).pluck(:id, :name).to_h

    totals.map do |account_id, tokens|
      {
        account_id: account_id,
        name: names[account_id],
        total_tokens: tokens,
        cost: costs[account_id].to_f.round(6)
      }
    end
  end
end
