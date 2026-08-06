require 'rails_helper'

RSpec.describe Ai::CatalogBootstrap do
  describe '.run!' do
    it 'creates the complete catalog and plan links in an empty database' do
      PlanAiModel.delete_all
      AiModelPrice.delete_all
      AiModel.delete_all
      AiConnection.delete_all
      plans = create_list(:plan, 2)

      described_class.run!

      expect(AiConnection.where(provider: :anthropic, modality: :direct, label: 'Anthropic API').count).to eq(1)
      expect(AiModel.where(canonical_id: described_class::CATALOG.map(&:first)).count).to eq(8)
      expect(AiModelPrice.where(superseded_at: nil).count).to eq(8)
      expect(PlanAiModel.where(plan: plans).count).to eq(16)

      expect { described_class.run! }.not_to(change do
        [AiConnection.count, AiModel.count, AiModelPrice.count, PlanAiModel.count]
      end)
    end

    it 'preserves models, prices, and plan restrictions already administered' do
      described_class.run!
      model = AiModel.find_by!(canonical_id: 'claude-haiku-4-5')
      connection = create(:ai_connection, modality: :bedrock)
      model.update!(
        ai_connection: connection,
        provider_model_id: 'bedrock.custom-haiku',
        display_name: 'Custom Haiku',
        default_for_provider: false
      )
      price = create(
        :ai_model_price,
        ai_model: model,
        input_cents_per_million: 777,
        output_cents_per_million: 999
      )
      linked_plan = create(:plan)
      restricted_plan = create(:plan)
      create(:plan_ai_model, plan: linked_plan, ai_model: model)

      described_class.run!

      expect(model.reload).to have_attributes(
        ai_connection: connection,
        provider_model_id: 'bedrock.custom-haiku',
        display_name: 'Custom Haiku',
        default_for_provider: false
      )
      expect(model.current_price).to eq(price)
      expect(restricted_plan.reload.ai_models).to be_empty
    end

    it 'rolls back all plan links when a link creation fails and seeds them on the next run' do
      plans = create_list(:plan, 2)
      described_class.run!
      PlanAiModel.delete_all

      creation_attempts = 0
      allow(PlanAiModel).to receive(:create!).and_wrap_original do |create_link, *args, **kwargs, &block|
        creation_attempts += 1
        raise StandardError, 'simulated plan link failure' if creation_attempts == 2

        create_link.call(*args, **kwargs, &block)
      end

      expect { described_class.run! }.to raise_error(StandardError, 'simulated plan link failure')
      expect(PlanAiModel.count).to eq(0)

      allow(PlanAiModel).to receive(:create!).and_call_original

      described_class.run!

      expect(PlanAiModel.where(plan: plans).count).to eq(16)
    end
  end
end
