class Survey::ResponsesController < ActionController::Base
  before_action :set_global_config
  def show; end

  private

  def set_global_config
    @global_config = GlobalConfig.get('LOGO_THUMBNAIL', 'BRAND_NAME', 'WIDGET_BRAND_URL', 'INSTALLATION_NAME')
    agency = Conversation.find_by(uuid: params[:id])&.account&.agency
    @global_config = agency.apply_branding(@global_config) if agency
  end
end
