require 'rails_helper'

RSpec.describe PlanAiModel do
  it 'rejects the same model twice in a plan' do
    plan = create(:plan)
    model = create(:ai_model)
    create(:plan_ai_model, plan: plan, ai_model: model)

    expect(build(:plan_ai_model, plan: plan, ai_model: model)).not_to be_valid
  end

  it 'lets the plan manage the join through ai_model_ids' do
    plan = create(:plan)
    model = create(:ai_model)

    plan.update!(ai_model_ids: [model.id])

    expect(plan.reload.ai_models).to contain_exactly(model)
  end
end
