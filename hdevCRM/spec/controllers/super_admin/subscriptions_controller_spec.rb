require 'rails_helper'

RSpec.describe 'Super Admin subscriptions', type: :request do
  let!(:super_admin) { create(:super_admin) }
  let!(:plan) { create(:plan) }
  let!(:subscription) { create(:subscription, plan: plan) }

  before do
    sign_in(super_admin, scope: :super_admin)
  end

  it 'lists subscriptions' do
    get '/super_admin/subscriptions'

    expect(response).to have_http_status(:success)
    expect(response.body).to include(plan.name)
  end

  it 'shows a subscription' do
    get "/super_admin/subscriptions/#{subscription.id}"

    expect(response).to have_http_status(:success)
    expect(response.body).to include(plan.name)
  end

  it 'updates plan and status by hand (courtesy path)' do
    other_plan = create(:plan)

    patch "/super_admin/subscriptions/#{subscription.id}",
          params: { subscription: { plan_id: other_plan.id, status: 'active' } }

    expect(response).to have_http_status(:redirect)
    subscription.reload
    expect(subscription.plan).to eq(other_plan)
    expect(subscription).to be_active
  end

  it 'has no create route (subscriptions are born in checkout)' do
    expect { post '/super_admin/subscriptions', params: { subscription: { plan_id: plan.id } } }
      .to raise_error(ActionController::RoutingError)
  end

  it 'has no destroy route (cancellation happens in Stripe)' do
    expect { delete "/super_admin/subscriptions/#{subscription.id}" }
      .to raise_error(ActionController::RoutingError)
  end
end
