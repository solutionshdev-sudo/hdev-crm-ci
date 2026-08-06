require 'rails_helper'

RSpec.describe Plan do
  describe 'validations' do
    it 'requires a name' do
      expect(build(:plan, name: nil)).not_to be_valid
    end

    it 'rejects negative prices' do
      expect(build(:plan, price_cents: -1)).not_to be_valid
    end

    it 'rejects negative limits' do
      expect(build(:plan, max_agents: -1)).not_to be_valid
    end

    it 'treats nil limits as valid (unlimited)' do
      expect(build(:plan, max_agents: nil, ai_monthly_tokens: nil)).to be_valid
    end

    it 'enforces unique stripe_price_id but allows multiple plans without one' do
      create(:plan, stripe_price_id: 'price_abc')
      expect(build(:plan, stripe_price_id: 'price_abc')).not_to be_valid
      expect(build(:plan, stripe_price_id: nil)).to be_valid
    end

    it 'accepts channel_limits with non-negative integers or explicit null' do
      expect(build(:plan, channel_limits: { 'Channel::Whatsapp' => 1, 'Channel::WebWidget' => nil })).to be_valid
    end

    it 'rejects channel_limits with negative or non-integer values' do
      expect(build(:plan, channel_limits: { 'Channel::Whatsapp' => -1 })).not_to be_valid
      expect(build(:plan, channel_limits: { 'Channel::Whatsapp' => 'muitos' })).not_to be_valid
    end
  end

  describe '#channel_limits_json (form do super admin)' do
    it 'round-trips the jsonb as text' do
      plan = build(:plan, channel_limits_json: '{"Channel::Whatsapp": 2}')
      expect(plan).to be_valid
      expect(plan.channel_limits).to eq('Channel::Whatsapp' => 2)
      expect(plan.channel_limits_json).to eq('{"Channel::Whatsapp":2}')
    end

    it 'treats blank input as no limits' do
      plan = build(:plan, channel_limits: { 'Channel::Whatsapp' => 1 })
      plan.channel_limits_json = ''
      expect(plan.channel_limits).to eq({})
    end

    it 'turns invalid JSON into a validation error instead of raising' do
      plan = build(:plan, channel_limits_json: '{oops')
      expect(plan).not_to be_valid
      expect(plan.errors[:channel_limits]).to be_present
    end
  end

  describe 'scopes' do
    it '.active excludes deactivated plans' do
      active_plan = create(:plan)
      create(:plan, active: false)
      expect(described_class.active).to contain_exactly(active_plan)
    end

    it '.ordered sorts by position' do
      second = create(:plan, position: 2)
      first = create(:plan, position: 1)
      expect(described_class.ordered).to eq([first, second])
    end
  end

  describe 'destroy' do
    it 'is blocked while subscriptions reference the plan' do
      subscription = create(:subscription)
      expect(subscription.plan.destroy).to be(false)
      expect(described_class.exists?(subscription.plan_id)).to be(true)
    end
  end
end
