require 'rails_helper'

RSpec.describe 'Agency Subscriptions API', type: :request do
  let(:agency) { create(:agency) }
  let(:agency_admin) { create(:user) }
  let(:outsider) { create(:user) }
  let(:plan) { create(:plan, :agency, :with_stripe_price) }

  before do
    create(:agency_user, agency: agency, user: agency_admin)
    allow(Stripe::Checkout::Session).to receive(:create)
      .and_return(instance_double(Stripe::Checkout::Session, url: 'https://stripe.test/checkout'))
    allow(Stripe::BillingPortal::Session).to receive(:create)
      .and_return(instance_double(Stripe::BillingPortal::Session, url: 'https://stripe.test/portal'))
  end

  describe 'POST /api/v1/agencies/:agency_id/subscription/checkout' do
    it 'returns the checkout url for the agency administrator' do
      post "/api/v1/agencies/#{agency.id}/subscription/checkout",
           params: { plan_id: plan.id },
           headers: agency_admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['url']).to eq('https://stripe.test/checkout')
      expect(agency.reload.subscription).to be_pending
    end

    it 'is reachable while the agency is pending_payment (first checkout)' do
      agency.update!(status: :pending_payment)

      post "/api/v1/agencies/#{agency.id}/subscription/checkout",
           params: { plan_id: plan.id },
           headers: agency_admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
    end

    it 'is reachable while the agency is suspended (paying is the way back in)' do
      agency.update!(status: :suspended)

      post "/api/v1/agencies/#{agency.id}/subscription/checkout",
           params: { plan_id: plan.id },
           headers: agency_admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
    end

    it 'refuses users outside the agency' do
      post "/api/v1/agencies/#{agency.id}/subscription/checkout",
           params: { plan_id: plan.id },
           headers: outsider.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 422 for a direct plan (type mismatch)' do
      direct_plan = create(:plan, :with_stripe_price)

      post "/api/v1/agencies/#{agency.id}/subscription/checkout",
           params: { plan_id: direct_plan.id },
           headers: agency_admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('This plan does not match this type of customer')
    end
  end

  describe 'POST /api/v1/agencies/:agency_id/subscription/portal' do
    it 'returns the portal url when there is a stripe customer' do
      create(:subscription, :active, :for_agency, owner: agency)

      post "/api/v1/agencies/#{agency.id}/subscription/portal",
           headers: agency_admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['url']).to eq('https://stripe.test/portal')
    end

    it 'returns 422 when the agency never paid' do
      post "/api/v1/agencies/#{agency.id}/subscription/portal",
           headers: agency_admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('No billing account yet. Complete a checkout first')
    end
  end
end
