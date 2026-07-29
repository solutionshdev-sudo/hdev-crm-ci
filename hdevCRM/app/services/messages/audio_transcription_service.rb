class Messages::AudioTranscriptionService
  include Llm::ExceptionTrackable

  # Teto da API de transcrição da OpenAI. Áudio maior é descartado em vez de
  # gastar a chamada pra tomar 413.
  MAX_FILE_SIZE = 25.megabytes

  # O registro de modelos traz `gpt-4o-mini-transcribe` como openai E azure.
  # Sem o provider explícito o RubyLLM escolhe por preferência interna e a
  # chamada pode sair pra Azure com uma chave da OpenAI.
  PROVIDER = :openai

  pattr_initialize [:attachment!]

  def perform
    return unless transcribable?

    text = transcribe
    return if text.blank?

    store(text)
  end

  private

  delegate :account, :message, to: :attachment

  def transcribable?
    attachment.audio? &&
      account.audio_transcriptions.present? &&
      attachment.file.attached? &&
      attachment.meta&.dig('transcribed_text').blank? &&
      attachment.file.byte_size <= MAX_FILE_SIZE &&
      api_key.present?
  end

  def transcribe
    # `blob.open` materializa um Tempfile com a extensão original — o provider
    # infere o formato do áudio pelo nome do arquivo.
    attachment.file.blob.open do |file|
      Llm::Config.with_api_key(api_key, api_base: api_base) do |context|
        # `RubyLLM::Context` só ganhou `#transcribe` depois da 1.15; a versão
        # fixada aqui expõe isso na classe, que aceita o context como kwarg.
        RubyLLM::Transcription.transcribe(file.path, model: model, provider: PROVIDER, context: context).text
      end
    end
  rescue StandardError => e
    capture_llm_exception(e, credential: { source: :system })
    nil
  end

  def store(text)
    attachment.update!(meta: (attachment.meta || {}).merge('transcribed_text' => text))
    # Repinta a bolha de áudio de quem já está com a conversa aberta.
    message&.reload&.send_update_event
  end

  def model
    Llm::FeatureRouter.resolve(feature: 'audio_transcription', account: account)[:model]
  end

  def api_key
    @api_key ||= InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
  end

  def api_base
    endpoint = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value.presence || 'https://api.openai.com/'
    "#{endpoint.chomp('/')}/v1"
  end

  def exception_tracking_account
    account
  end
end
