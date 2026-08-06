require 'rails_helper'

RSpec.describe Ai::ModelResolver do
  let(:agency) { create(:agency) }
  let(:account) { create(:account, agency: agency) }
  let(:resolver) { described_class.new(account: account) }

  def grant_plan!(owner, *models)
    plan = create(:plan)
    plan.update!(ai_model_ids: models.map(&:id))
    create(:subscription, :active, owner: owner, plan: plan)
    plan
  end

  describe '#resolve!' do
    it 'resolves a live catalog model for an account without a plan (grandfathering)' do
      model = create(:ai_model)

      resolution = resolver.resolve!(model.canonical_id)

      expect(resolution.model).to eq(model)
      expect(resolution.connection).to eq(model.ai_connection)
      expect(resolution.provider_model_id).to eq(model.provider_model_id)
    end

    it 'uses the direct subscription plan as the gate' do
      allowed = create(:ai_model)
      blocked = create(:ai_model)
      grant_plan!(account, allowed)

      expect(resolver.resolve!(allowed.canonical_id).model).to eq(allowed)
      expect(resolver.resolve!(blocked.canonical_id).model).to eq(allowed) # degrada pro liberado
    end

    it 'falls back to the agency plan when the account has no subscription' do
      allowed = create(:ai_model)
      grant_plan!(agency, allowed)
      blocked = create(:ai_model)

      expect(resolver.resolve!(blocked.canonical_id).model).to eq(allowed)
    end

    it 'prefers the default_for_provider among the allowed models on fallback' do
      cheap = create(:ai_model, default_for_provider: true)
      other = create(:ai_model)
      blocked = create(:ai_model)
      grant_plan!(account, cheap, other)

      expect(resolver.resolve!(blocked.canonical_id).model).to eq(cheap)
    end

    it 'logs a warning when it degrades' do
      allowed = create(:ai_model)
      blocked = create(:ai_model)
      grant_plan!(account, allowed)
      allow(Rails.logger).to receive(:warn)

      resolver.resolve!(blocked.canonical_id)

      expect(Rails.logger).to have_received(:warn).with(/#{blocked.canonical_id}/)
    end

    it 'degrades an unknown canonical_id (legacy free string) to the default' do
      fallback = create(:ai_model, default_for_provider: true)
      grant_plan!(account, fallback)

      expect(resolver.resolve!('string-livre-antiga').model).to eq(fallback)
    end

    it 'skips deprecated models' do
      dead = create(:ai_model, deprecated_at: 1.day.ago)
      live = create(:ai_model, default_for_provider: true)
      grant_plan!(account, dead, live)

      expect(resolver.resolve!(dead.canonical_id).model).to eq(live)
    end

    it 'raises when the plan releases no model at all (strict gate)' do
      plan = create(:plan)
      create(:subscription, :active, owner: account, plan: plan)

      expect { resolver.resolve!('claude-haiku-4-5') }.to raise_error(Ai::ModelNotAllowedError)
    end

    it 'raises when the connection is disabled' do
      model = create(:ai_model)
      model.ai_connection.update!(active: false)

      expect { resolver.resolve!(model.canonical_id) }.to raise_error(Ai::ModelNotAllowedError)
    end

    it 'is rescuable by the existing quota rescue paths' do
      expect(Ai::ModelNotAllowedError.ancestors).to include(Ai::QuotaExceededError)
    end
  end

  describe '#allowed_models' do
    it 'returns the whole live catalog when no plan is in the chain' do
      model = create(:ai_model)
      expect(resolver.allowed_models).to include(model)
    end

    it 'returns only the plan selection when a plan exists' do
      allowed = create(:ai_model)
      create(:ai_model)
      grant_plan!(account, allowed)

      expect(resolver.allowed_models).to contain_exactly(allowed)
    end
  end
end
