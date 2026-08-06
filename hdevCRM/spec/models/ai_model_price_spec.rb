require 'rails_helper'

RSpec.describe AiModelPrice do
  it 'supersedes the previous current price of the same model on create' do
    model = create(:ai_model)
    old_price = create(:ai_model_price, ai_model: model)

    create(:ai_model_price, ai_model: model, input_cents_per_million: 900)

    expect(old_price.reload.superseded_at).to be_present
    expect(model.current_price.input_cents_per_million).to eq(900)
  end

  it 'does not touch prices of other models' do
    other_price = create(:ai_model_price)

    create(:ai_model_price)

    expect(other_price.reload.superseded_at).to be_nil
  end
end
