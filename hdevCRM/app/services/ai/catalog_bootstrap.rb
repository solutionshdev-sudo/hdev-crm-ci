module Ai
  class CatalogBootstrap
    CATALOG = [
      ['claude-fable-5', 'Claude Fable 5', false],
      ['claude-opus-5', 'Claude Opus 5', false],
      ['claude-opus-4-8', 'Claude Opus 4.8', false],
      ['claude-opus-4-7', 'Claude Opus 4.7', false],
      ['claude-opus-4-6', 'Claude Opus 4.6', false],
      ['claude-sonnet-5', 'Claude Sonnet 5', false],
      ['claude-sonnet-4-6', 'Claude Sonnet 4.6', false],
      ['claude-haiku-4-5', 'Claude Haiku 4.5', true]
    ].freeze

    PRICES_CENTS = {
      'claude-fable-5' => [1000, 5000],
      'claude-opus-5' => [500, 2500],
      'claude-opus-4-8' => [500, 2500],
      'claude-opus-4-7' => [500, 2500],
      'claude-opus-4-6' => [500, 2500],
      'claude-sonnet-5' => [300, 1500],
      'claude-sonnet-4-6' => [300, 1500],
      'claude-haiku-4-5' => [100, 500]
    }.freeze

    class << self
      def run!
        connection = AiConnection.find_or_create_by!(provider: :anthropic, modality: :direct, label: 'Anthropic API')
        models = CATALOG.map { |canonical_id, display_name, default_for_provider| seed_model(connection, canonical_id, display_name, default_for_provider) }

        seed_plan_links(models)
      end

      private

      def seed_model(connection, canonical_id, display_name, default_for_provider)
        model = AiModel.find_or_create_by!(canonical_id: canonical_id) do |record|
          record.ai_connection = connection
          record.provider_model_id = canonical_id
          record.display_name = display_name
          record.default_for_provider = default_for_provider
        end

        seed_price(model, canonical_id)
        model
      end

      def seed_price(model, canonical_id)
        return if model.current_price.present?

        input_cents, output_cents = PRICES_CENTS.fetch(canonical_id)
        AiModelPrice.create!(
          ai_model: model,
          input_cents_per_million: input_cents,
          output_cents_per_million: output_cents,
          effective_from: Time.zone.now
        )
      end

      def seed_plan_links(models)
        return unless PlanAiModel.none?

        Plan.find_each do |plan|
          models.each { |model| PlanAiModel.create!(plan: plan, ai_model: model) }
        end
      end
    end
  end
end
