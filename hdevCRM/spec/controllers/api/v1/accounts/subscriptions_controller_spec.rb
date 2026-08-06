require 'rails_helper'

RSpec.describe 'Account Subscriptions API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:plan) { create(:plan, :with_stripe_price) }

  before do
    allow(Stripe::Checkout::Session).to receive(:create)
      .and_return(Stripe::Checkout::Session.construct_from(id: 'cs_spec', url: 'https://stripe.test/checkout'))
    allow(Stripe::BillingPortal::Session).to receive(:create)
      .and_return(Stripe::BillingPortal::Session.construct_from(id: 'bps_spec', url: 'https://stripe.test/portal'))
  end

  describe 'POST /api/v1/accounts/:account_id/subscription/checkout' do
    it 'returns the checkout url for an account administrator' do
      post "/api/v1/accounts/#{account.id}/subscription/checkout",
           params: { plan_id: plan.id },
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['url']).to eq('https://stripe.test/checkout')
      expect(account.reload.subscription).to be_pending
    end

    it 'is reachable for a suspended account (paying is the way back in)' do
      account.update!(status: :suspended)

      post "/api/v1/accounts/#{account.id}/subscription/checkout",
           params: { plan_id: plan.id },
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
    end

    it 'refuses agents' do
      post "/api/v1/accounts/#{account.id}/subscription/checkout",
           params: { plan_id: plan.id },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'refuses accounts managed by an agency' do
      agency = create(:agency)
      account.update!(agency: agency)

      post "/api/v1/accounts/#{account.id}/subscription/checkout",
           params: { plan_id: plan.id },
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['error']).to eq('Billing for this account is managed by its agency')
    end

    it 'returns 422 with the reason for an unusable plan' do
      priceless = create(:plan)

      post "/api/v1/accounts/#{account.id}/subscription/checkout",
           params: { plan_id: priceless.id },
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('This plan is not available for checkout')
    end

    it 'returns 422 when a plan is already granted' do
      create(:subscription, :active, owner: account, plan: plan)

      post "/api/v1/accounts/#{account.id}/subscription/checkout",
           params: { plan_id: plan.id },
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('There is already an active plan. Use the billing portal to change it')
    end
  end

  describe 'POST /api/v1/accounts/:account_id/subscription/portal' do
    it 'returns the portal url when there is a stripe customer' do
      create(:subscription, :active, owner: account, plan: plan)

      post "/api/v1/accounts/#{account.id}/subscription/portal",
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['url']).to eq('https://stripe.test/portal')
    end

    it 'returns 422 when the account never paid' do
      post "/api/v1/accounts/#{account.id}/subscription/portal",
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('No billing account yet. Complete a checkout first')
    end
  end
end
