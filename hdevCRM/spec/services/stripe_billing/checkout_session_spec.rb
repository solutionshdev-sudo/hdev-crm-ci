require 'rails_helper'

RSpec.describe StripeBilling::CheckoutSession do
  let(:account) { create(:account) }
  let(:plan) { create(:plan, :with_stripe_price) }
  # construct_from cria o objeto real da gem — instance_double falharia se os
  # atributos forem dinâmicos (method_missing do StripeObject).
  let(:stripe_session) { Stripe::Checkout::Session.construct_from(id: 'cs_spec', url: 'https://stripe.test/checkout') }

  before do
    allow(Stripe::Checkout::Session).to receive(:create).and_return(stripe_session)
  end

  it 'creates a pending subscription and opens the stripe session referencing it' do
    url = described_class.new(owner: account, plan: plan).call

    expect(url).to eq('https://stripe.test/checkout')
    subscription = account.reload.subscription
    expect(subscription).to be_pending
    expect(subscription.plan).to eq(plan)
    expect(Stripe::Checkout::Session).to have_received(:create).with(
      hash_including(mode: 'subscription',
                     client_reference_id: subscription.id.to_s,
                     line_items: [{ price: plan.stripe_price_id, quantity: 1 }])
    )
  end

  it 'reuses the existing subscription row instead of duplicating it' do
    existing = create(:subscription, owner: account, plan: create(:plan), status: 'canceled')

    described_class.new(owner: account, plan: plan).call

    expect(Subscription.where(owner: account).count).to eq(1)
    existing.reload
    expect(existing.plan).to eq(plan)
    expect(existing).to be_pending
  end

  it 'passes the known stripe customer so the checkout reuses it' do
    create(:subscription, owner: account, plan: plan, status: 'canceled', stripe_customer_id: 'cus_back')

    described_class.new(owner: account, plan: plan).call

    expect(Stripe::Checkout::Session).to have_received(:create).with(hash_including(customer: 'cus_back'))
  end

  it 'refuses a plan without a stripe price' do
    priceless = create(:plan)

    expect { described_class.new(owner: account, plan: priceless).call }
      .to raise_error(StripeBilling::Error, I18n.t('errors.subscriptions.plan_unavailable'))
  end

  it 'refuses an inactive plan' do
    inactive = create(:plan, :with_stripe_price, active: false)

    expect { described_class.new(owner: account, plan: inactive).call }
      .to raise_error(StripeBilling::Error, I18n.t('errors.subscriptions.plan_unavailable'))
  end

  it 'refuses a plan whose type does not match the owner' do
    agency_plan = create(:plan, :agency, :with_stripe_price)

    expect { described_class.new(owner: account, plan: agency_plan).call }
      .to raise_error(StripeBilling::Error, I18n.t('errors.subscriptions.plan_type_mismatch'))
  end

  it 'refuses when a plan is already granted (plan changes go through the portal)' do
    create(:subscription, :active, owner: account, plan: plan)

    expect { described_class.new(owner: account, plan: plan).call }
      .to raise_error(StripeBilling::Error, I18n.t('errors.subscriptions.already_subscribed'))
  end

  it 'accepts an agency owner with an agency plan' do
    agency = create(:agency)
    agency_plan = create(:plan, :agency, :with_stripe_price)

    described_class.new(owner: agency, plan: agency_plan).call

    expect(agency.reload.subscription).to be_pending
  end
end
