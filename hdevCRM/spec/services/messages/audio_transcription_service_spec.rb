require 'rails_helper'

RSpec.describe Messages::AudioTranscriptionService do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:message) { create(:message, account: account, conversation: conversation) }
  let(:transcription) { instance_double(RubyLLM::Transcription, text: 'olá, preciso de ajuda com o pedido') }
  let(:context) { instance_double(RubyLLM::Context) }

  def audio_attachment(filename: 'sample.mp3', content_type: 'audio/mpeg')
    attachment = message.attachments.new(account_id: account.id, file_type: :audio)
    attachment.file.attach(io: Rails.root.join("spec/assets/#{filename}").open, filename: filename, content_type: content_type)
    attachment.save!
    attachment
  end

  before do
    create(:installation_config, name: 'CAPTAIN_OPEN_AI_API_KEY', value: 'test-key')
    account.update!(audio_transcriptions: true)
    allow(Llm::Config).to receive(:with_api_key).and_yield(context)
    allow(context).to receive(:transcribe).and_return(transcription)
  end

  describe '#perform' do
    it 'stores the transcription in the attachment meta' do
      attachment = audio_attachment

      described_class.new(attachment: attachment).perform

      expect(attachment.reload.meta['transcribed_text']).to eq('olá, preciso de ajuda com o pedido')
    end

    it 'exposes the transcription through the audio push payload' do
      attachment = audio_attachment

      described_class.new(attachment: attachment).perform

      expect(attachment.reload.push_event_data[:transcribed_text]).to eq('olá, preciso de ajuda com o pedido')
    end

    it 'dispatches a message update so open conversations repaint' do
      attachment = audio_attachment
      allow(Rails.configuration.dispatcher).to receive(:dispatch)

      described_class.new(attachment: attachment).perform

      expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(
        'message.updated', anything, hash_including(message: message)
      )
    end

    it 'resolves the model from the audio_transcription feature and pins the openai provider' do
      attachment = audio_attachment

      described_class.new(attachment: attachment).perform

      expect(context).to have_received(:transcribe).with(
        anything, model: Llm::Models.default_model_for('audio_transcription'), provider: :openai
      )
    end

    it 'honours the account level model override' do
      account.update!(captain_models: { 'audio_transcription' => 'whisper-1' })
      attachment = audio_attachment

      described_class.new(attachment: attachment).perform

      expect(context).to have_received(:transcribe).with(anything, model: 'whisper-1', provider: :openai)
    end

    context 'when it should not run' do
      it 'skips when the account setting is off' do
        attachment = audio_attachment
        account.update!(audio_transcriptions: false)

        described_class.new(attachment: attachment).perform

        expect(context).not_to have_received(:transcribe)
      end

      it 'skips when there is no api key configured' do
        InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY').destroy!
        attachment = audio_attachment

        described_class.new(attachment: attachment).perform

        expect(context).not_to have_received(:transcribe)
      end

      it 'skips an attachment that was already transcribed' do
        attachment = audio_attachment
        attachment.update!(meta: { 'transcribed_text' => 'já transcrito' })

        described_class.new(attachment: attachment).perform

        expect(context).not_to have_received(:transcribe)
        expect(attachment.reload.meta['transcribed_text']).to eq('já transcrito')
      end

      it 'skips a non audio attachment' do
        attachment = message.attachments.create!(account_id: account.id, file_type: :image, external_url: 'https://example.com/a.png')

        described_class.new(attachment: attachment).perform

        expect(context).not_to have_received(:transcribe)
      end

      it 'skips a file over the provider size limit' do
        attachment = audio_attachment
        allow(attachment.file).to receive(:byte_size).and_return(described_class::MAX_FILE_SIZE + 1)

        described_class.new(attachment: attachment).perform

        expect(context).not_to have_received(:transcribe)
      end

      it 'does not store an empty transcription' do
        allow(transcription).to receive(:text).and_return('')
        attachment = audio_attachment

        described_class.new(attachment: attachment).perform

        expect(attachment.reload.meta).to be_blank
      end
    end

    context 'when the provider fails' do
      before do
        allow(context).to receive(:transcribe).and_raise(StandardError, 'boom')
      end

      it 'swallows the error and leaves the attachment untouched' do
        attachment = audio_attachment

        expect { described_class.new(attachment: attachment).perform }.not_to raise_error
        expect(attachment.reload.meta).to be_blank
      end

      it 'reports the failure' do
        attachment = audio_attachment
        tracker = instance_double(ChatwootExceptionTracker, capture_exception: true)
        allow(ChatwootExceptionTracker).to receive(:new).and_return(tracker)

        described_class.new(attachment: attachment).perform

        expect(tracker).to have_received(:capture_exception)
      end
    end
  end
end
