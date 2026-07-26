class Api::V1::Accounts::DealPipelinesController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_pipeline, only: [:show, :update, :destroy, :reorder_stages]

  def index
    DealPipeline.ensure_default!(Current.account)
    @pipelines = Current.account.deal_pipelines.active.includes(:deal_stages).order(:position)
  end

  def show; end

  def create
    @pipeline = Current.account.deal_pipelines.create!(permitted_params)
    (params[:stages] || []).each_with_index do |stage, index|
      @pipeline.deal_stages.create!(stage_params(stage).merge(account_id: Current.account.id, position: index + 1))
    end
    render :show
  end

  def update
    @pipeline.update!(permitted_params)
    (params[:stages] || []).each_with_index do |stage, index|
      attrs = stage_params(stage).merge(position: index + 1)
      if stage[:id].present?
        @pipeline.deal_stages.find(stage[:id]).update!(attrs)
      else
        @pipeline.deal_stages.create!(attrs.merge(account_id: Current.account.id))
      end
    end
    render :show
  end

  def destroy
    @pipeline.update!(archived_at: Time.current)
    head :ok
  end

  def reorder_stages
    params.require(:stage_ids).each_with_index do |stage_id, index|
      @pipeline.deal_stages.find(stage_id).update!(position: index + 1)
    end
    render :show
  end

  private

  def fetch_pipeline
    @pipeline = Current.account.deal_pipelines.find(params[:id])
  end

  def permitted_params
    params.permit(:name, :description, :position, :is_default)
  end

  def stage_params(stage)
    stage.permit(:name, :color, :probability, :stage_type)
  end

  def check_authorization
    authorize(DealPipeline)
  end
end
