require 'rails_helper'

RSpec.describe 'Webhooks::StripeController', type: :request do
  let(:webhook_secret) { 'whsec_spec' }
  let(:account) { create(:account) }
  let(:plan) { create(:plan, :with_stripe_price) }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('STRIPE_WEBHOOK_SECRET', nil).and_return(webhook_secret)
  end

  # Assinatura REAL da gem — stubar o construct_event aqui deixaria a
  # verificação sem prova nenhuma.
  def signed_headers(payload, secret: webhook_secret, timestamp: Time.now) # rubocop:disable Rails/TimeZone
    signature = Stripe::Webhook::Signature.compute_signature(timestamp, payload, secret)
    { 'CONTENT_TYPE' => 'application/json',
      'Stripe-Signature' => Stripe::Webhook::Signature.generate_header(timestamp, signature) }
  end

  def post_event(id:, type:, object:, secret: webhook_secret)
    payload = { 'id' => id, 'object' => 'event', 'type' => type, 'data' => { 'object' => object } }.to_json
    post '/webhooks/stripe', params: payload, headers: signed_headers(payload, secret: secret)
  end

  describe 'signature verification' do
    it 'returns 401 when the webhook secret is not configured' do
      allow(ENV).to receive(:fetch).with('STRIPE_WEBHOOK_SECRET', nil).and_return(nil)

      post_event(id: 'evt_1', type: 'invoice.paid', object: {})

      expect(response).to have_http_status(:unauthorized)
      expect(StripeWebhookEvent.count).to eq(0)
    end

    it 'returns 401 for a payload signed with the wrong secret' do
      post_event(id: 'evt_1', type: 'invoice.paid', object: {}, secret: 'whsec_wrong')

      expect(response).to have_http_status(:unauthorized)
      expect(StripeWebhookEvent.count).to eq(0)
    end

    it 'returns 400 for a correctly signed body that is not JSON' do
      payload = 'not json'
      post '/webhooks/stripe', params: payload, headers: signed_headers(payload)

      expect(response).to have_http_status(:bad_request)
    end
  end

  it 'acknowledges unhandled event types without recording them' do
    post_event(id: 'evt_1', type: 'customer.created', object: {})

    expect(response).to have_http_status(:ok)
    expect(StripeWebhookEvent.count).to eq(0)
  end

  describe 'dispatch' do
    it 'activates the pending subscription on checkout.session.completed' do
      subscription = create(:subscription, owner: account, plan: plan)

      post_event(id: 'evt_checkout', type: 'checkout.session.completed',
                 object: { 'client_reference_id' => subscription.id.to_s,
                           'customer' => 'cus_f7', 'subscription' => 'sub_f7' })

      expect(response).to have_http_status(:ok)
      expect(subscription.reload).to be_active
      expect(StripeWebhookEvent.find_by(stripe_event_id: 'evt_checkout')).to be_processed
    end

    it 'marks the subscription past_due on invoice.payment_failed' do
      subscription = create(:subscription, :active, owner: account, plan: plan)

      post_event(id: 'evt_fail', type: 'invoice.payment_failed',
                 object: { 'customer' => subscription.stripe_customer_id })

      expect(subscription.reload).to be_past_due
    end

    it 'activates and stores the period end on invoice.paid' do
      subscription = create(:subscription, owner: account, plan: plan,
                                           stripe_subscription_id: 'sub_f7', stripe_customer_id: 'cus_f7')
      period_end = 1.month.from_now.to_i

      post_event(id: 'evt_paid', type: 'invoice.paid',
                 object: { 'customer' => 'cus_f7',
                           'parent' => { 'subscription_details' => { 'subscription' => 'sub_f7' } },
                           'lines' => { 'data' => [{ 'period' => { 'end' => period_end } }] } })

      subscription.reload
      expect(subscription).to be_active
      expect(subscription.current_period_end.to_i).to eq(period_end)
    end

    it 'swaps the plan on customer.subscription.updated' do
      subscription = create(:subscription, :active, owner: account, plan: plan)
      other_plan = create(:plan, :with_stripe_price)

      post_event(id: 'evt_upd', type: 'customer.subscription.updated',
                 object: { 'id' => subscription.stripe_subscription_id, 'status' => 'active',
                           'items' => { 'data' => [{ 'price' => { 'id' => other_plan.stripe_price_id } }] } })

      expect(subscription.reload.plan).to eq(other_plan)
    end

    it 'cancels the subscription and suspends the owner on customer.subscription.deleted' do
      subscription = create(:subscription, :active, owner: account, plan: plan)

      post_event(id: 'evt_del', type: 'customer.subscription.deleted',
                 object: { 'id' => subscription.stripe_subscription_id })

      expect(subscription.reload).to be_canceled
      expect(account.reload).to be_suspended
    end
  end

  describe 'idempotency' do
    it 'applies the same event id only once' do
      subscription = create(:subscription, owner: account, plan: plan)
      object = { 'client_reference_id' => subscription.id.to_s, 'subscription' => 'sub_f7' }

      post_event(id: 'evt_once', type: 'checkout.session.completed', object: object)
      expect(subscription.reload).to be_active

      # Se o replay mutasse de novo, o status voltaria a active.
      subscription.update!(status: 'pending')
      post_event(id: 'evt_once', type: 'checkout.session.completed', object: object)

      expect(response).to have_http_status(:ok)
      expect(subscription.reload).to be_pending
      expect(StripeWebhookEvent.where(stripe_event_id: 'evt_once').count).to eq(1)
    end
  end

  describe 'orphan events' do
    it 'records the event as ignored and still acknowledges with 200' do
      post_event(id: 'evt_orphan', type: 'invoice.paid', object: { 'customer' => 'cus_ghost' })

      expect(response).to have_http_status(:ok)
      event = StripeWebhookEvent.find_by(stripe_event_id: 'evt_orphan')
      expect(event).to be_ignored
      expect(event.error).to include('cus_ghost')
    end
  end
end
