require 'rails_helper'

RSpec.describe StripeBilling::EventHandler do
  let(:account) { create(:account) }
  let(:plan) { create(:plan, :with_stripe_price) }

  def build_event(type, object)
    create(:stripe_webhook_event,
           event_type: type,
           payload: { 'id' => 'evt_spec', 'type' => type, 'data' => { 'object' => object } })
  end

  describe 'checkout.session.completed' do
    let(:subscription) { create(:subscription, owner: account, plan: plan) }

    it 'activates the subscription referenced by client_reference_id and stores the stripe ids' do
      event = build_event('checkout.session.completed',
                          'client_reference_id' => subscription.id.to_s,
                          'customer' => 'cus_f7',
                          'subscription' => 'sub_f7')

      expect(described_class.new(event).call).to be_nil

      subscription.reload
      expect(subscription).to be_active
      expect(subscription.stripe_customer_id).to eq('cus_f7')
      expect(subscription.stripe_subscription_id).to eq('sub_f7')
    end

    it 'returns a reason when client_reference_id matches nothing' do
      event = build_event('checkout.session.completed', 'client_reference_id' => '0', 'customer' => 'cus_x')

      expect(described_class.new(event).call).to include('client_reference_id')
    end
  end

  describe 'invoice.paid' do
    let(:subscription) do
      create(:subscription, owner: account, plan: plan, status: 'past_due',
                            stripe_subscription_id: 'sub_f7', stripe_customer_id: 'cus_f7')
    end

    it 'activates via parent.subscription_details.subscription and stores the max line period end' do
      period_end = 1.month.from_now.to_i
      event = build_event('invoice.paid',
                          'customer' => 'cus_f7',
                          'parent' => { 'subscription_details' => { 'subscription' => subscription.stripe_subscription_id } },
                          'lines' => { 'data' => [
                            { 'period' => { 'end' => 1.day.from_now.to_i } },
                            { 'period' => { 'end' => period_end } }
                          ] })

      expect(described_class.new(event).call).to be_nil

      subscription.reload
      expect(subscription).to be_active
      expect(subscription.current_period_end.to_i).to eq(period_end)
    end

    it 'falls back to the stripe customer id and tolerates an empty lines list' do
      event = build_event('invoice.paid', 'customer' => subscription.stripe_customer_id, 'lines' => { 'data' => [] })

      expect(described_class.new(event).call).to be_nil
      expect(subscription.reload).to be_active
    end

    it 'returns a reason when no subscription matches' do
      event = build_event('invoice.paid', 'customer' => 'cus_unknown')

      expect(described_class.new(event).call).to include('cus_unknown')
    end
  end

  describe 'invoice.payment_failed' do
    it 'marks the subscription past_due' do
      subscription = create(:subscription, :active, owner: account, plan: plan)
      event = build_event('invoice.payment_failed', 'customer' => subscription.stripe_customer_id)

      expect(described_class.new(event).call).to be_nil
      expect(subscription.reload).to be_past_due
    end
  end

  describe 'customer.subscription.updated' do
    let(:subscription) { create(:subscription, :active, owner: account, plan: plan) }

    def updated_event(status:, price_id: nil, period_end: nil)
      item = {}
      item['price'] = { 'id' => price_id } if price_id
      item['current_period_end'] = period_end if period_end
      build_event('customer.subscription.updated',
                  'id' => subscription.stripe_subscription_id,
                  'status' => status,
                  'items' => { 'data' => [item] })
    end

    it 'swaps the plan when the portal changed the price' do
      other_plan = create(:plan, :with_stripe_price)
      period_end = 2.months.from_now.to_i
      event = updated_event(status: 'active', price_id: other_plan.stripe_price_id, period_end: period_end)

      expect(described_class.new(event).call).to be_nil

      subscription.reload
      expect(subscription.plan).to eq(other_plan)
      expect(subscription).to be_active
      expect(subscription.current_period_end.to_i).to eq(period_end)
    end

    it 'returns a reason when the price has no local plan' do
      event = updated_event(status: 'active', price_id: 'price_unknown')

      expect(described_class.new(event).call).to include('price_unknown')
      expect(subscription.reload.plan).to eq(plan)
    end

    it 'maps trialing to active' do
      subscription.update!(status: 'past_due')
      event = updated_event(status: 'trialing')

      described_class.new(event).call

      expect(subscription.reload).to be_active
    end

    it 'maps unpaid to past_due' do
      event = updated_event(status: 'unpaid')

      described_class.new(event).call

      expect(subscription.reload).to be_past_due
    end

    it 'leaves canceled to the deleted event and does not touch the status' do
      event = updated_event(status: 'canceled')

      described_class.new(event).call

      expect(subscription.reload).to be_active
    end

    it 'leaves paused untouched' do
      event = updated_event(status: 'paused')

      described_class.new(event).call

      expect(subscription.reload).to be_active
    end

    it 'returns a reason when the stripe subscription is unknown' do
      subscription.update!(stripe_subscription_id: 'sub_other')
      event = build_event('customer.subscription.updated', 'id' => 'sub_ghost', 'status' => 'active')

      expect(described_class.new(event).call).to include('sub_ghost')
    end
  end

  describe 'customer.subscription.deleted' do
    it 'cancels the subscription and suspends the owner' do
      subscription = create(:subscription, :active, owner: account, plan: plan)
      event = build_event('customer.subscription.deleted', 'id' => subscription.stripe_subscription_id)

      expect(described_class.new(event).call).to be_nil

      expect(subscription.reload).to be_canceled
      expect(account.reload).to be_suspended
    end
  end

  it 'reads payloads with symbol keys the same way (first pass before the jsonb round-trip)' do
    subscription = create(:subscription, owner: account, plan: plan)
    event = StripeWebhookEvent.new(
      stripe_event_id: 'evt_sym', event_type: 'checkout.session.completed',
      payload: { data: { object: { client_reference_id: subscription.id.to_s, subscription: 'sub_sym' } } }
    )

    expect(described_class.new(event).call).to be_nil
    expect(subscription.reload).to be_active
  end
end
