class Api::V1::Accounts::Chatbots::SessionsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_chatbot

  def index
    @sessions = @chatbot.chatbot_sessions.order(id: :desc).limit(50)
  end

  def destroy
    session = @chatbot.chatbot_sessions.find(params[:id])
    session.update!(status: :aborted) if session.active?
    session.conversation.bot_handoff! if session.conversation.pending?
    head :ok
  end

  private

  def fetch_chatbot
    @chatbot = Current.account.chatbots.find(params[:chatbot_id])
  end

  def check_authorization
    authorize(Chatbot)
  end
end
