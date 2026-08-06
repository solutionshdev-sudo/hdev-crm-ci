class Api::V1::Accounts::Deals::ActivitiesController < Api::V1::Accounts::BaseController
  def index
    deal = Current.account.deals.find(params[:deal_id])
    authorize(deal, :show?)
    @activities = deal.deal_activities.includes(:user, :from_stage, :to_stage).order(id: :desc).limit(100)
  end
end
