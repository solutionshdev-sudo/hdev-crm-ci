module Whatsapp::IncomingMessageServiceHelpers
  # Opt-out (Fase 2 §2.2): ancorado, só bate se a mensagem inteira (tirando espaços e
  # pontuação final) for uma das palavras de saída — não um trecho dentro de uma frase maior.
  OPT_OUT_REGEX = /\A\s*(?:stop|pare|parar|sair|cancelar|descadastrar|unsubscribe)\s*[!.]*\s*\z/i

  def download_attachment_file(attachment_payload)
    Down.download(inbox.channel.media_url(attachment_payload[:id]), headers: inbox.channel.api_headers)
  end

  # Extraído de Whatsapp::IncomingMessageBaseService#process_messages (Metrics/CyclomaticComplexity):
  # tipo não suportado, dedupe de webhook duplicado (Meta manda o mesmo evento mais de uma vez em
  # contas mal configuradas) e falha no lock atômico (SET NX do Redis contra corrida de workers).
  def skip_incoming_message?
    unprocessable_message_type?(message_type) ||
      find_message_by_source_id(messages_data.first[:id]) ||
      !lock_message_source_id!
  end

  # Extraído de Whatsapp::IncomingMessageBaseService#process_messages: contato ausente após
  # set_contact, ou bloqueado (mute global) fora de eco de mensagem já enviada pelo próprio canal.
  def contact_ready_to_process?
    set_contact
    return false unless @contact
    return false if @contact.blocked? && !outgoing_echo

    true
  end

  def conversation_params
    {
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id
    }
  end

  def processed_params
    @processed_params ||= params
  end

  def account
    @account ||= inbox.account
  end

  def message_type
    messages_data.first[:type]
  end

  def message_content(message)
    # TODO: map interactive messages back to button messages in chatwoot
    message.dig(:text, :body) ||
      message.dig(:button, :text) ||
      message.dig(:interactive, :button_reply, :title) ||
      message.dig(:interactive, :list_reply, :title) ||
      message.dig(:name, :formatted_name)
  end

  def file_content_type(file_type)
    return :image if %w[image sticker].include?(file_type)
    return :audio if %w[audio voice].include?(file_type)
    return :video if ['video'].include?(file_type)
    return :location if ['location'].include?(file_type)
    return :contact if ['contacts'].include?(file_type)

    :file
  end

  def unprocessable_message_type?(message_type)
    %w[reaction ephemeral request_welcome].include?(message_type)
  end

  def processed_waid(waid)
    Whatsapp::PhoneNumberNormalizationService.new(inbox).normalize_and_find_contact_by_provider(waid, :cloud)
  end

  def whatsapp_phone_number(identifier)
    identifier = identifier.to_s
    return if identifier.blank?
    return unless identifier.match?(/\A\d{1,15}\z/)

    identifier
  end

  def error_webhook_event?(message)
    message.key?('errors')
  end

  def log_error(message)
    Rails.logger.warn "Whatsapp Error: #{message['errors'][0]['title']} - contact: #{message['from']}"
  end

  def process_in_reply_to(message)
    @in_reply_to_external_id = message['context']&.[]('id')
  end

  def referral_attributes(message)
    return {} if outgoing_echo

    message[:referral]&.to_h&.deep_stringify_keys || {}
  end

  # O webhook traz o timestamp real da mensagem (epoch em segundos); sem ele, mensagem
  # de backfill de histórico nasce com horário do processamento e aparece fora de ordem
  # na conversa (a tela ordena por created_at). Futuro = relógio torto do aparelho: trava
  # em agora. Ausente/zero: nil deixa o Rails carimbar a hora atual, como antes.
  def message_timestamp(message)
    ts = message[:timestamp].to_i
    return if ts <= 0

    [Time.zone.at(ts), Time.zone.now].min
  end

  def find_message_by_source_id(source_id)
    return unless source_id

    @message = Message.find_by(source_id: source_id)
  end

  def lock_message_source_id!
    return false if messages_data.blank?

    Whatsapp::MessageDedupLock.new(messages_data.first[:id]).acquire!
  end

  # Opt-out (Fase 2 §2.2): só texto livre digitado aciona — button/interactive replies
  # (ex.: item de menu do chatbot chamado "Cancelar") não contam como STOP.
  # Retorna true quando o contato acabou de sair (pra quem chamou decidir se grava a nota
  # de atividade só depois que a transaction em volta commitar).
  #
  # Idempotente: contato que já saiu não reaciona em cada "PARAR" repetido — sem o guard,
  # cada repetição regravaria o mesmo valor e enfileiraria outra nota de atividade.
  def detect_opt_out!
    return false if @contact.automation_opted_out?
    return false unless messages_data.first.dig(:text, :body).to_s.match?(OPT_OUT_REGEX)

    @contact.update!(automation_opted_out: true)
    true
  end

  def create_opt_out_activity_message
    activity_message_params = {
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      message_type: :activity,
      content: I18n.t('conversations.activity.opt_out.contact_opted_out')
    }
    ::Conversations::ActivityMessageJob.perform_later(@conversation, activity_message_params)
  end
end
