require 'rails_helper'

RSpec.describe 'Super Admin stripe webhook events', type: :request do
  let!(:super_admin) { create(:super_admin) }
  let!(:event) { create(:stripe_webhook_event, event_type: 'invoice.paid') }

  before do
    sign_in(super_admin, scope: :super_admin)
  end

  it 'lists events' do
    get '/super_admin/stripe_webhook_events'

    expect(response).to have_http_status(:success)
    expect(response.body).to include(event.stripe_event_id)
  end

  it 'filters by status' do
    ignored = create(:stripe_webhook_event, status: 'ignored', error: 'no local subscription')

    get '/super_admin/stripe_webhook_events', params: { search: 'ignored:' }

    expect(response).to have_http_status(:success)
    expect(response.body).to include(ignored.stripe_event_id)
    expect(response.body).not_to include(event.stripe_event_id)
  end

  it 'shows an event with the reason' do
    event.mark_ignored!('no local subscription for cus_x')

    get "/super_admin/stripe_webhook_events/#{event.id}"

    expect(response).to have_http_status(:success)
    expect(response.body).to include('no local subscription for cus_x')
  end

  # show_exceptions está ligado no test env: rota inexistente vira 404, não
  # ActionController::RoutingError.
  it 'has no edit route (audit trail is read-only)' do
    get "/super_admin/stripe_webhook_events/#{event.id}/edit"

    expect(response).to have_http_status(:not_found)
  end
end
