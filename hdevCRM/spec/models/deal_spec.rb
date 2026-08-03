require 'rails_helper'

RSpec.describe Deal do
  let(:account) { create(:account) }
  let(:pipeline) { create(:deal_pipeline, account: account) }
  let(:open_stage) { create(:deal_stage, account: account, deal_pipeline: pipeline, stage_type: :open) }
  let(:won_stage) { create(:deal_stage, :won, account: account, deal_pipeline: pipeline) }
  let(:lost_stage) { create(:deal_stage, :lost, account: account, deal_pipeline: pipeline) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account) }

  describe '#apply_stage_outcome' do
    let(:deal) { create(:deal, account: account, deal_pipeline: pipeline, deal_stage: open_stage, contact: contact) }

    it 'marks the deal as won and sets closed_at when moved to a won stage' do
      deal.update!(deal_stage: won_stage)

      expect(deal.reload).to be_won
      expect(deal.closed_at).to be_present
    end

    it 'marks the deal as lost and sets closed_at when moved to a lost stage' do
      deal.update!(deal_stage: lost_stage, lost_reason: 'preço')

      expect(deal.reload).to be_lost
      expect(deal.closed_at).to be_present
    end

    it 'reopens the deal when moved back to an open stage, clearing closed_at and lost_reason' do
      deal.update!(deal_stage: lost_stage, lost_reason: 'preço')
      other_open_stage = create(:deal_stage, account: account, deal_pipeline: pipeline, stage_type: :open)

      deal.update!(deal_stage: other_open_stage)

      expect(deal.reload).to be_open
      expect(deal.closed_at).to be_nil
      expect(deal.lost_reason).to be_nil
    end

    it 'does not overwrite an already set closed_at' do
      time = 2.days.ago
      deal.update!(deal_stage: won_stage, closed_at: time)

      expect(deal.reload.closed_at).to be_within(1.second).of(time)
    end

    it 'directly created into a won stage is already won' do
      new_deal = create(:deal, account: account, deal_pipeline: pipeline, deal_stage: won_stage, contact: contact)

      expect(new_deal).to be_won
      expect(new_deal.closed_at).to be_present
    end
  end

  describe 'lost_reason validation' do
    let(:deal) { create(:deal, account: account, deal_pipeline: pipeline, deal_stage: open_stage, contact: contact) }

    it 'is invalid when moved to a lost stage without a lost_reason' do
      deal.deal_stage = lost_stage

      expect(deal).to be_invalid
      expect(deal.errors[:lost_reason]).to include(I18n.t('errors.models.deal.lost_reason_required'))
    end

    it 'is valid when moved to a lost stage with a lost_reason' do
      deal.deal_stage = lost_stage
      deal.lost_reason = 'preço'

      expect(deal).to be_valid
    end

    it 'is invalid when created directly into a lost stage without a lost_reason' do
      new_deal = build(:deal, account: account, deal_pipeline: pipeline, deal_stage: lost_stage, contact: contact)

      expect(new_deal).to be_invalid
      expect(new_deal.errors[:lost_reason]).to include(I18n.t('errors.models.deal.lost_reason_required'))
    end

    it 'is valid when created directly into a lost stage with a lost_reason' do
      new_deal = build(:deal, account: account, deal_pipeline: pipeline, deal_stage: lost_stage, contact: contact,
                              lost_reason: 'sem orçamento')

      expect(new_deal).to be_valid
    end

    it 'clears the lost_reason when the deal is reopened' do
      deal.update!(deal_stage: lost_stage, lost_reason: 'preço')

      deal.update!(deal_stage: open_stage)

      expect(deal.reload.lost_reason).to be_nil
    end

    it 'does not require a lost_reason on saves that do not change the stage' do
      deal.update!(deal_stage: lost_stage, lost_reason: 'preço')
      deal.update_column(:lost_reason, nil) # simula um registro antigo sem motivo, sem passar pela validação

      expect(deal.update(value: 999)).to be true
    end
  end

  describe 'event dispatch' do
    before do
      allow(Rails.configuration.dispatcher).to receive(:dispatch)
    end

    context 'when the deal is created' do
      it 'dispatches DEAL_CREATED when created into an open stage' do
        deal = create(:deal, account: account, deal_pipeline: pipeline, deal_stage: open_stage, contact: contact, conversation: conversation)

        expect(Rails.configuration.dispatcher).to have_received(:dispatch)
          .with(described_class::DEAL_CREATED, kind_of(Time), deal: deal, conversation: conversation, changed_attributes: kind_of(Hash))
      end

      it 'dispatches only DEAL_CREATED, never a stage event, when created directly into a won stage' do
        deal = create(:deal, account: account, deal_pipeline: pipeline, deal_stage: won_stage, contact: contact, conversation: conversation)

        expect(Rails.configuration.dispatcher).to have_received(:dispatch)
          .with(described_class::DEAL_CREATED, kind_of(Time), deal: deal, conversation: conversation, changed_attributes: kind_of(Hash))
        expect(Rails.configuration.dispatcher).not_to have_received(:dispatch).with(described_class::DEAL_WON, kind_of(Time), anything)
        expect(Rails.configuration.dispatcher).not_to have_received(:dispatch).with(described_class::DEAL_STAGE_CHANGED, kind_of(Time), anything)
      end

      it 'dispatches only DEAL_CREATED, never a stage event, when created directly into a lost stage' do
        deal = create(:deal, account: account, deal_pipeline: pipeline, deal_stage: lost_stage, contact: contact, conversation: conversation,
                             lost_reason: 'preço')

        expect(Rails.configuration.dispatcher).to have_received(:dispatch)
          .with(described_class::DEAL_CREATED, kind_of(Time), deal: deal, conversation: conversation, changed_attributes: kind_of(Hash))
        expect(Rails.configuration.dispatcher).not_to have_received(:dispatch).with(described_class::DEAL_LOST, kind_of(Time), anything)
        expect(Rails.configuration.dispatcher).not_to have_received(:dispatch).with(described_class::DEAL_STAGE_CHANGED, kind_of(Time), anything)
      end
    end

    context 'when the deal is updated' do
      let!(:deal) { create(:deal, account: account, deal_pipeline: pipeline, deal_stage: open_stage, contact: contact, conversation: conversation) }

      it 'dispatches DEAL_STAGE_CHANGED when moved between open stages' do
        other_open_stage = create(:deal_stage, account: account, deal_pipeline: pipeline, stage_type: :open)
        deal.update!(deal_stage: other_open_stage)
        changed_attributes = deal.previous_changes

        expect(Rails.configuration.dispatcher).to have_received(:dispatch)
          .with(described_class::DEAL_STAGE_CHANGED, kind_of(Time), deal: deal, conversation: conversation, changed_attributes: changed_attributes)
      end

      it 'dispatches DEAL_WON instead of DEAL_STAGE_CHANGED when moved to a won stage' do
        deal.update!(deal_stage: won_stage)

        expect(Rails.configuration.dispatcher).to have_received(:dispatch)
          .with(described_class::DEAL_WON, kind_of(Time), deal: deal, conversation: conversation, changed_attributes: kind_of(Hash))
        expect(Rails.configuration.dispatcher).not_to have_received(:dispatch).with(described_class::DEAL_STAGE_CHANGED, kind_of(Time), anything)
      end

      it 'dispatches DEAL_LOST instead of DEAL_STAGE_CHANGED when moved to a lost stage' do
        deal.update!(deal_stage: lost_stage, lost_reason: 'preço')

        expect(Rails.configuration.dispatcher).to have_received(:dispatch)
          .with(described_class::DEAL_LOST, kind_of(Time), deal: deal, conversation: conversation, changed_attributes: kind_of(Hash))
        expect(Rails.configuration.dispatcher).not_to have_received(:dispatch).with(described_class::DEAL_STAGE_CHANGED, kind_of(Time), anything)
      end

      it 'does not dispatch a stage event when a non-stage attribute changes' do
        deal.update!(value: 999)

        expect(Rails.configuration.dispatcher).not_to have_received(:dispatch).with(described_class::DEAL_STAGE_CHANGED, kind_of(Time), anything)
        expect(Rails.configuration.dispatcher).not_to have_received(:dispatch).with(described_class::DEAL_WON, kind_of(Time), anything)
        expect(Rails.configuration.dispatcher).not_to have_received(:dispatch).with(described_class::DEAL_LOST, kind_of(Time), anything)
      end
    end
  end
end
