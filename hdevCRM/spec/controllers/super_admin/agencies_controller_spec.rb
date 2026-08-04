require 'rails_helper'

RSpec.describe 'Super Admin agencies API', type: :request do
  let!(:super_admin) { create(:super_admin) }
  let!(:agency) { create(:agency) }

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
