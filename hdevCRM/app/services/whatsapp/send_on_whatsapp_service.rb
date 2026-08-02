class Whatsapp::SendOnWhatsappService < Base::SendOnChannelService
  private

  # Teto de reagendamentos do gate anti-ban (Fase 2, plano §2.3): depois de 3
  # postpones consecutivos ainda barrados, desiste e nega em vez de reagendar
  # pra sempre (ex.: relógio de servidor torto, conta sem provider_config são).
  MAX_GATE_RESCHEDULES = 3

  def channel_class
    Channel::Whatsapp
  end

  def perform_reply
    decision = send_gate_decision

    if decision.is_a?(Hash) && decision[:deny]
      deny_message!(decision[:deny])
    elsif decision.is_a?(Hash) && decision[:postpone_until]
      handle_postponed_message(decision)
    else
      send_via_channel
    end
  end

  # Consulta o gate puro (Messaging::SendGateService) — `automated` reusa o
  # MESMO predicado que já barra opt-out/blocked em Base::SendOnChannelService,
  # não duplica a decisão do que conta como "automatizado".
  def send_gate_decision
    Messaging::SendGateService.new(
      channel: channel,
      contact: contact,
      automated: automated_message?,
      now: Time.current
    ).call
  end

  def send_via_channel
    should_send_template_message = template_params.present? || !message.conversation.can_reply?
    if should_send_template_message
      send_template_message
    else
      send_session_message
    end
    # Contador diário só sobe quando o envio de fato sai (allow) — nunca em
    # postpone/deny. Não-baileys nunca chega aqui armado (ban_risk: false).
    Messaging::BaileysSendCounter.new(channel: channel).increment! if channel.baileys?
  end

  def handle_postponed_message(decision)
    reschedule_count = gate_reschedule_count
    if reschedule_count >= MAX_GATE_RESCHEDULES
      deny_message!(:reschedule_limit_exceeded, last_reason: decision[:reason])
    else
      notify_human_postponed(decision[:postpone_until]) if reschedule_count.zero? && !automated_message?
      bump_gate_reschedule_count!(reschedule_count + 1)
      # Jitter espalha a manada das 7h; o gate continua determinístico.
      ::SendReplyJob.set(wait_until: decision[:postpone_until] + rand(0..900).seconds).perform_later(message.id)
    end
  end

  # Cap diário vale pra mensagem humana também (o número banido não distingue
  # quem mandou) — mas só avisa uma vez, no PRIMEIRO reagendamento (não a cada
  # retry), pra não spammar a conversa. Postpone de mensagem automatizada fica
  # silencioso de propósito: é volume esperado do motor, não uma exceção que o
  # agente precise ver.
  def notify_human_postponed(postpone_until)
    activity_message_params = {
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :activity,
      content: I18n.t('conversations.activity.antiban.message_delayed', time: I18n.l(postpone_until, format: :short))
    }
    ::Conversations::ActivityMessageJob.perform_later(conversation, activity_message_params)
  end

  def deny_message!(reason, last_reason: nil)
    message.update!(status: :failed)
    create_gate_denied_activity_message(reason, last_reason)
  end

  def create_gate_denied_activity_message(reason, last_reason)
    activity_message_params = {
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :activity,
      content: gate_denied_content(reason, last_reason)
    }
    ::Conversations::ActivityMessageJob.perform_later(conversation, activity_message_params)
  end

  def gate_denied_content(reason, last_reason)
    I18n.t('conversations.activity.antiban.message_not_sent', reason: gate_denied_reason_text(reason, last_reason))
  end

  def gate_denied_reason_text(reason, last_reason)
    return I18n.t("conversations.activity.antiban.reasons.#{reason}") unless reason == :reschedule_limit_exceeded

    I18n.t('conversations.activity.antiban.reasons.reschedule_limit_exceeded',
           last_reason: I18n.t("conversations.activity.antiban.reasons.#{last_reason}"))
  end

  # `content_attributes` guarda payload de exibição por canal (email, items,
  # image_type); `additional_attributes` é o balde de metadado interno de
  # bookkeeping (ver Avatar::AvatarFromUrlJob) — é aqui que o teto de
  # reagendamentos do gate vive.
  def gate_reschedule_count
    (message.additional_attributes || {})['antiban_reschedule_count'].to_i
  end

  def bump_gate_reschedule_count!(count)
    attrs = (message.additional_attributes || {}).merge('antiban_reschedule_count' => count)
    message.update!(additional_attributes: attrs)
  end

  def send_template_message
    processor = Whatsapp::TemplateProcessorService.new(
      channel: channel,
      template_params: template_params,
      message: message
    )

    name, namespace, lang_code, processed_parameters = processor.call

    if name.blank?
      message.update!(status: :failed, external_error: I18n.t('errors.api.template.not_found_or_invalid'))
      return
    end

    message_id = channel.send_template(message.conversation.contact_inbox.source_id, {
                                         name: name,
                                         namespace: namespace,
                                         lang_code: lang_code,
                                         parameters: processed_parameters
                                       }, message)
    message.update!(source_id: message_id) if message_id.present?
  end

  def send_session_message
    message_id = channel.send_message(message.conversation.contact_inbox.source_id, message)
    message.update!(source_id: message_id) if message_id.present?
  end

  def template_params
    message.additional_attributes && message.additional_attributes['template_params']
  end
end
