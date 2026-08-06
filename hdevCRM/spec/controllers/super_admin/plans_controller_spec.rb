require 'rails_helper'

RSpec.describe 'Super Admin plans API', type: :request do
  let!(:super_admin) { create(:super_admin) }

  describe 'GET /super_admin/plans' do
    it 'lists plans ordered by position' do
      create(:plan, name: 'Escala', position: 2)
      create(:plan, name: 'Base', position: 1)
      sign_in(super_admin, scope: :super_admin)

      get '/super_admin/plans'

      expect(response).to have_http_status(:success)
      expect(response.body.index('Base')).to be < response.body.index('Escala')
    end
  end

  describe 'POST /super_admin/plans' do
    it 'creates a plan with limits and channel_limits from the JSON text field' do
      sign_in(super_admin, scope: :super_admin)

      post '/super_admin/plans',
           params: {
             plan: {
               name: 'Agência Pro',
               plan_type: 'agency',
               price_cents: 49_900,
               max_agents: 10,
               max_inboxes: 20,
               max_baileys_instances: 3,
               max_client_accounts: 15,
               ai_monthly_tokens: 2_000_000,
               channel_limits_json: '{"Channel::Whatsapp": 3}',
               active: true,
               position: 1
             }
           }

      expect(response).to have_http_status(:redirect)
      plan = Plan.find_by(name: 'Agência Pro')
      expect(plan.max_client_accounts).to eq(15)
      expect(plan.channel_limits).to eq('Channel::Whatsapp' => 3)
    end

    it 're-renders the form when channel_limits_json is invalid JSON' do
      sign_in(super_admin, scope: :super_admin)

      post '/super_admin/plans',
           params: { plan: { name: 'Quebrado', plan_type: 'direct', price_cents: 0, channel_limits_json: '{oops' } }

      expect(Plan.find_by(name: 'Quebrado')).to be_nil
    end
  end

  describe 'PATCH /super_admin/plans/{plan_id}' do
    it 'updates the plan limits' do
      plan = create(:plan, max_agents: 3)
      sign_in(super_admin, scope: :super_admin)

      patch "/super_admin/plans/#{plan.id}", params: { plan: { name: plan.name, max_agents: 5 } }

      expect(response).to have_http_status(:redirect)
      expect(plan.reload.max_agents).to eq(5)
    end
  end

  describe 'DELETE /super_admin/plans/{plan_id}' do
    it 'does not delete a plan with subscriptions (restrict_with_error)' do
      subscription = create(:subscription)
      sign_in(super_admin, scope: :super_admin)

      delete "/super_admin/plans/#{subscription.plan_id}"

      expect(Plan.exists?(subscription.plan_id)).to be(true)
    end
  end
end
