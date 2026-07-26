# Session management for baileys (unofficial WhatsApp) inboxes: QR/pairing
# status, reconnect and logout. Thin proxy over baileys-service — the
# microservice owns connection state.
class Api::V1::Accounts::Channels::BaileysController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox
  before_action :validate_baileys_channel

  def status
    render json: session_service.status
  rescue Whatsapp::BaileysClient::ApiError => e
    render json: { error: e.message }, status: :service_unavailable
  end

  def connect
    render json: session_service.connect!(use_pairing_code: params[:use_pairing_code].present?)
  rescue Whatsapp::BaileysClient::ApiError => e
    render json: { error: e.message }, status: :service_unavailable
  end

  def logout
    session_service.logout!
    head :ok
  rescue Whatsapp::BaileysClient::ApiError => e
    render json: { error: e.message }, status: :service_unavailable
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:id])
    authorize @inbox, :update?
  end

  def validate_baileys_channel
    return if @inbox.channel.is_a?(Channel::Whatsapp) && @inbox.channel.baileys?

    render json: { error: 'Not a baileys WhatsApp inbox' }, status: :unprocessable_entity
  end

  def session_service
    @session_service ||= Whatsapp::BaileysSessionService.new(channel: @inbox.channel)
  end
end
