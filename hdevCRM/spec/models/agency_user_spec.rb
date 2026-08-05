require 'rails_helper'

RSpec.describe AgencyUser do
  describe 'associations' do
    it { is_expected.to belong_to(:agency) }
    it { is_expected.to belong_to(:user) }
  end

  describe 'uniqueness' do
    it 'does not allow the same user twice in an agency' do
      agency_user = create(:agency_user)
      duplicate = build(:agency_user, agency: agency_user.agency, user: agency_user.user)
      expect(duplicate).not_to be_valid
    end

    it 'allows the same user in different agencies' do
      agency_user = create(:agency_user)
      other = build(:agency_user, agency: create(:agency), user: agency_user.user)
      expect(other).to be_valid
    end
  end
end
