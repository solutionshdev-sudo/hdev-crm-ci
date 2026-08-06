require 'rails_helper'

RSpec.describe Messages::AudioTranscriptionJob do
  subject(:job) { described_class.perform_later(attachment.id) }

  let(:message) { create(:message) }
  let(:attachment) { message.attachments.create!(account_id: message.account_id, file_type: :audio, external_url: 'https://example.com/a.mp3') }
  let(:service) { instance_double(Messages::AudioTranscriptionService, perform: true) }

  it 'enqueues the job on the low queue' do
    expect { job }.to have_enqueued_job(described_class).on_queue('low')
  end

  it 'hands the attachment to the transcription service' do
    allow(Messages::AudioTranscriptionService).to receive(:new).with(attachment: attachment).and_return(service)

    described_class.perform_now(attachment.id)

    expect(service).to have_received(:perform)
  end

  it 'does nothing when the attachment is gone' do
    allow(Messages::AudioTranscriptionService).to receive(:new)

    described_class.perform_now(attachment.id + 1)

    expect(Messages::AudioTranscriptionService).not_to have_received(:new)
  end
end
