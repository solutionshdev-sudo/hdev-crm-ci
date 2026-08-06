module Ai
  # Preço vem de ai_model_prices (linha vigente = superseded_at IS NULL) com
  # cache em memória de 5 min — compute_totals roda a cada AiUsageEvent e não
  # pode custar um SELECT por evento. Modelo fora do catálogo cai no DEFAULT
  # (nunca gravar custo zero). A antiga constante PRICES virou seed de
  # migration (20260806000004) e saiu do runtime.
  class Pricing
    DEFAULT = { input: 5.0, output: 25.0 }.freeze
    CACHE_TTL = 5.minutes

    class << self
      def for_model(model)
        cents = cents_for(model)
        { input: cents[:input] / 100.0, output: cents[:output] / 100.0 }
      end

      def cost(model, input_tokens, output_tokens)
        cents = cents_for(model)
        total_cents_per_million = (input_tokens.to_i * cents[:input]) + (output_tokens.to_i * cents[:output])
        total_cents_per_million / 100_000_000.0
      end

      # Specs e troca de preço pelo painel derrubam o cache do processo.
      def reset_cache!
        @cache = {}
      end

      private

      def cents_for(model)
        @cache ||= {}
        entry = @cache[model.to_s]
        return entry[:value] if entry && entry[:at] > CACHE_TTL.ago

        value = lookup(model.to_s) || { input: (DEFAULT[:input] * 100).to_i, output: (DEFAULT[:output] * 100).to_i }
        @cache[model.to_s] = { value: value, at: Time.zone.now }
        value
      end

      def lookup(canonical_id)
        price = AiModelPrice.joins(:ai_model)
                            .where(ai_models: { canonical_id: canonical_id }, superseded_at: nil)
                            .order(effective_from: :desc)
                            .first
        return nil if price.blank?

        { input: price.input_cents_per_million, output: price.output_cents_per_million }
      end
    end
  end
end
