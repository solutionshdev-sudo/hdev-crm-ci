class Api::V1::Accounts::ChatbotsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_chatbot, only: [:show, :update, :destroy, :clone, :toggle]

  def index
    @chatbots = Current.account.chatbots.includes(:inboxes).order(:id)
  end

  def show; end

  def create
    @chatbot = Current.account.chatbots.create!(
      permitted_params.merge(created_by_id: current_user.id, updated_by_id: current_user.id)
    )
    sync_inboxes
    render :show
  end

  def update
    @chatbot.assign_attributes(permitted_params.merge(updated_by_id: current_user.id))
    @chatbot.flow_version += 1 if @chatbot.flow_changed?
    @chatbot.save!
    sync_inboxes
    render :show
  end

  def destroy
    @chatbot.destroy!
    head :ok
  end

  def clone
    copy = @chatbot.dup
    copy.name = "#{@chatbot.name} (cópia)"
    copy.status = :draft
    copy.created_by_id = current_user.id
    copy.save!
    @chatbot = copy
    render :show
  end

  def toggle
    @chatbot.update!(status: @chatbot.active? ? :inactive : :active)
    render :show
  end

  private

  def fetch_chatbot
    @chatbot = Current.account.chatbots.find(params[:id])
  end

  def permitted_params
    params.require(:chatbot).permit(:name, :description, :status, flow: {}, settings: {})
  end

  def sync_inboxes
    return if params[:inbox_ids].blank?

    @chatbot.chatbot_inboxes.where.not(inbox_id: params[:inbox_ids]).destroy_all
    Array(params[:inbox_ids]).each do |inbox_id|
      inbox = Current.account.inboxes.find(inbox_id)
      @chatbot.chatbot_inboxes.find_or_create_by!(inbox: inbox)
    end
  end

  def check_authorization
    authorize(Chatbot)
  end
end
