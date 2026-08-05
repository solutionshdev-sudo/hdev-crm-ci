require 'rails_helper'

RSpec.describe 'Super Admin agencies API', type: :request do
  let!(:super_admin) { create(:super_admin) }
  let!(:agency) { create(:agency) }

  describe 'GET /super_admin/agencies/{agency_id}' do
    context 'when it is an authenticated user' do
      it 'keeps showing a suspended agency (F5-T2 §5.4: super admin continua acessando)' do
        agency.update!(status: :suspended)
        sign_in(super_admin, scope: :super_admin)

        get "/super_admin/agencies/#{agency.id}"

        expect(response).to have_http_status(:success)
        expect(response.body).to include(agency.name)
      end

      it 'keeps showing a pending_payment agency' do
        agency.update!(status: :pending_payment)
        sign_in(super_admin, scope: :super_admin)

        get "/super_admin/agencies/#{agency.id}"

        expect(response).to have_http_status(:success)
        expect(response.body).to include(agency.name)
      end
    end
  end

  describe 'PATCH /super_admin/agencies/{agency_id}' do
    context 'when it is an authenticated user' do
      it 'updates the status to pending_payment (F5-T2 §5.2 select do super admin)' do
        sign_in(super_admin, scope: :super_admin)

        patch "/super_admin/agencies/#{agency.id}",
              params: {
                agency: {
                  name: agency.name,
                  slug: agency.slug,
                  status: 'pending_payment'
                }
              }

        expect(response).to have_http_status(:redirect)
        expect(agency.reload.status).to eq('pending_payment')
      end

      it 'saves the suspension reason into settings via store_accessor (F5-T2 §5.2, sem migration)' do
        sign_in(super_admin, scope: :super_admin)
        reason = 'Abuso confirmado — assinatura cancelada no Stripe em 04/08'

        patch "/super_admin/agencies/#{agency.id}",
              params: {
                agency: {
                  name: agency.name,
                  slug: agency.slug,
                  status: 'suspended',
                  suspended_reason: reason
                }
              }

        expect(response).to have_http_status(:redirect)
        agency.reload
        expect(agency.status).to eq('suspended')
        expect(agency.suspended_reason).to eq(reason)
        expect(agency.settings['suspended_reason']).to eq(reason)
      end
    end
  end
end
