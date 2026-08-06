require 'rails_helper'

RSpec.describe StripeWebhookEvent do
  describe 'validations' do
    it 'requires a unique stripe_event_id' do
      event = create(:stripe_webhook_event)
      expect(build(:stripe_webhook_event, stripe_event_id: event.stripe_event_id)).not_to be_valid
    end
  end

  describe 'processing state' do
    it 'marks as processed with a timestamp and clears previous errors' do
      event = create(:stripe_webhook_event, status: 'failed', error: 'boom')

      event.mark_processed!

      expect(event.reload).to be_processed
      expect(event.processed_at).to be_present
      expect(event.error).to be_nil
    end

    it 'marks as failed with the error message' do
      event = create(:stripe_webhook_event)

      event.mark_failed!('assinatura inválida')

      expect(event.reload).to be_failed
      expect(event.error).to eq('assinatura inválida')
    end

    it 'marks as ignored keeping the reason and a timestamp' do
      event = create(:stripe_webhook_event)

      event.mark_ignored!('no local subscription for sub_123')

      expect(event.reload).to be_ignored
      expect(event.processed_at).to be_present
      expect(event.error).to eq('no local subscription for sub_123')
    end
  end
end
