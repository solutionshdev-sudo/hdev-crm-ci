class Api::V1::Accounts::DealsController < Api::V1::Accounts::BaseController
  RESULTS_PER_STAGE = 20

  before_action :check_authorization
  before_action :fetch_deal, only: [:show, :update, :destroy, :move]

  def index
    @deals = filtered_deals
             .includes(:contact, :assignee, :deal_stage)
             .order(:position)
    # Board pagination happens per column: the client passes stage_id +
    # page to "load more" inside one stage.
    @deals = @deals.page(params[:page] || 1).per(RESULTS_PER_STAGE) if params[:stage_id].present?
  end

  def show; end

  def create
    pipeline = Current.account.deal_pipelines.find(params[:deal][:deal_pipeline_id])
    stage = pipeline.deal_stages.find(params[:deal][:deal_stage_id])
    @deal = Current.account.deals.new(permitted_params)
    @deal.deal_pipeline = pipeline
    @deal.deal_stage = stage
    @deal.created_by_id = current_user.id
    @deal.position = (stage.deals.minimum(:position).to_f - 1024)
    @deal.save!
    render :show
  end

  def update
    @deal.update!(permitted_params)
    render :show
  end

  def destroy
    @deal.destroy!
    head :ok
  end

  def move
    stage = Current.account.deal_pipelines.find(@deal.deal_pipeline_id).deal_stages.find(params[:stage_id])
    Deals::MoveService.new(
      deal: @deal,
      stage: stage,
      before_deal_id: params[:before_deal_id],
      after_deal_id: params[:after_deal_id]
    ).perform
    render :show
  end

  private

  def fetch_deal
    @deal = Current.account.deals.find(params[:id])
  end

  def filtered_deals
    deals = Current.account.deals
    deals = deals.in_pipeline(params[:pipeline_id]) if params[:pipeline_id].present?
    deals = deals.where(deal_stage_id: params[:stage_id]) if params[:stage_id].present?
    deals = deals.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?
    deals = deals.where(contact_id: params[:contact_id]) if params[:contact_id].present?
    deals = deals.where(conversation_id: params[:conversation_id]) if params[:conversation_id].present?
    deals = deals.where(status: params[:status]) if params[:status].present?
    deals = deals.where('deals.title ILIKE ?', "%#{params[:q]}%") if params[:q].present?
    deals
  end

  def permitted_params
    params.require(:deal).permit(
      :title, :description, :value, :currency, :contact_id, :conversation_id,
      :assignee_id, :expected_close_on, :lost_reason, :deal_stage_id,
      custom_attributes: {}
    )
  end

  def check_authorization
    authorize(Deal)
  end
end
