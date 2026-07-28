module Ai
  # Price map used to convert tokens into USD cost. Values are USD per
  # 1M tokens, taken from Anthropic's public price list (2026-07). Unknown
  # models fall back to DEFAULT so usage is never recorded with zero cost.
  class Pricing
    PRICES = {
      'claude-fable-5' => { input: 10.0, output: 50.0 },
      'claude-opus-5' => { input: 5.0, output: 25.0 },
      'claude-opus-4-8' => { input: 5.0, output: 25.0 },
      'claude-opus-4-7' => { input: 5.0, output: 25.0 },
      'claude-opus-4-6' => { input: 5.0, output: 25.0 },
      'claude-sonnet-5' => { input: 3.0, output: 15.0 },
      'claude-sonnet-4-6' => { input: 3.0, output: 15.0 },
      'claude-haiku-4-5' => { input: 1.0, output: 5.0 }
    }.freeze

    DEFAULT = { input: 5.0, output: 25.0 }.freeze

    def self.for_model(model)
      PRICES.fetch(model.to_s, DEFAULT)
    end

    def self.cost(model, input_tokens, output_tokens)
      prices = for_model(model)
      ((input_tokens.to_i * prices[:input]) + (output_tokens.to_i * prices[:output])) / 1_000_000.0
    end
  end
end
