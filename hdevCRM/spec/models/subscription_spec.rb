require 'rails_helper'

RSpec.describe Subscription do
  describe 'associations' do
    it { is_expected.to belong_to(:owner) }
    it { is_expected.to belong_to(:plan) }
  end

  describe 'uniqueness' do
    it 'allows a single subscription per owner' do
      subscription = create(:subscription)
      duplicate = build(:subscription, owner: subscription.owner)
      expect(duplicate).not_to be_valid
    end

    it 'allows one subscription per owner across owner types' do
      create(:subscription)
      expect(build(:subscription, :for_agency)).to be_valid
    end
  end

  describe '#grants_plan?' do
    it 'grants for active and past_due, denies for pending and canceled' do
      expect(build(:subscription, status: 'active').grants_plan?).to be(true)
      expect(build(:subscription, status: 'past_due').grants_plan?).to be(true)
      expect(build(:subscription, status: 'pending').grants_plan?).to be(false)
      expect(build(:subscription, status: 'canceled').grants_plan?).to be(false)
    end
  end

  describe '#activate!' do
    it 'activates and stores the stripe references' do
      subscription = create(:subscription)
      period_end = 1.month.from_now

      subscription.activate!(stripe_subscription_id: 'sub_123', current_period_end: period_end)

      expect(subscription.reload).to be_active
      expect(subscription.stripe_subscription_id).to eq('sub_123')
      expect(subscription.current_period_end).to be_within(1.second).of(period_end)
    end

    it 'keeps existing stripe references when called without arguments' do
      subscription = create(:subscription, :active, status: 'past_due')
      original_id = subscription.stripe_subscription_id

      subscription.activate!

      expect(subscription.reload).to be_active
      expect(subscription.stripe_subscription_id).to eq(original_id)
    end

    it 'reactivates an account waiting for payment' do
      account = create(:account, status: 'pending_payment')
      subscription = create(:subscription, owner: account)

      subscription.activate!

      expect(account.reload).to be_active
    end

    it 'reactivates an agency suspended for non payment' do
      agency = create(:agency, status: 'suspended')
      subscription = create(:subscription, :for_agency, owner: agency)

      subscription.activate!

      expect(agency.reload).to be_active
    end
  end

  describe '#mark_past_due!' do
    it 'flags the subscription without touching the owner' do
      subscription = create(:subscription, :active)

      subscription.mark_past_due!

      expect(subscription.reload).to be_past_due
      expect(subscription.owner.reload).to be_active
    end
  end

  describe '#cancel!' do
    it 'cancels and suspends the owner account' do
      subscription = create(:subscription, :active)

      subscription.cancel!

      expect(subscription.reload).to be_canceled
      expect(subscription.owner.reload).to be_suspended
    end

    it 'cancels and suspends the owner agency' do
      subscription = create(:subscription, :for_agency)

      subscription.cancel!

      expect(subscription.owner.reload).to be_suspended
    end
  end
end
