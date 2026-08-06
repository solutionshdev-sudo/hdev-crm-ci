require 'rails_helper'

RSpec.describe 'Super Admin AI connections API', type: :request do
  let!(:super_admin) { create(:super_admin) }

  it 'never renders the api_key value, only the mask' do
    create(:ai_connection, label: 'Principal', api_key: 'sk-super-secreto-9876')
    sign_in(super_admin, scope: :super_admin)

    get '/super_admin/ai_connections'
    expect(response.body).not_to include('sk-super-secreto')

    get "/super_admin/ai_connections/#{AiConnection.last.id}"
    expect(response.body).not_to include('sk-super-secreto')
    expect(response.body).to include('••••9876')
  end

  it 'creates a connection with an encrypted key from the form' do
    sign_in(super_admin, scope: :super_admin)

    post '/super_admin/ai_connections',
         params: { ai_connection: { provider: 'anthropic', modality: 'direct', label: 'Nova', api_key: 'sk-nova' } }

    expect(AiConnection.find_by(label: 'Nova').api_key).to eq('sk-nova')
  end

  it 'keeps the stored key when the password field comes back blank on update' do
    connection = create(:ai_connection, label: 'Principal', api_key: 'sk-guardada')
    sign_in(super_admin, scope: :super_admin)

    put "/super_admin/ai_connections/#{connection.id}",
        params: { ai_connection: { provider: 'anthropic', modality: 'direct', label: 'Renomeada', api_key: '' } }

    expect(connection.reload.label).to eq('Renomeada')
    expect(connection.api_key).to eq('sk-guardada')
  end
end
