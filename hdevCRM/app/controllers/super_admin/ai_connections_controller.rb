class SuperAdmin::AiConnectionsController < SuperAdmin::ApplicationController
  # Campo de senha em branco no edit significa "não mexer na chave", não
  # apagar — o form nunca pré-preenche Field::Password.
  def resource_params
    permitted = super
    permitted.delete(:api_key) if permitted[:api_key].blank?
    permitted.delete(:aws_secret_access_key) if permitted[:aws_secret_access_key].blank?
    permitted
  end
end
