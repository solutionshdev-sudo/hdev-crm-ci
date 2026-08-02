#######################################
# To create an external channel reply service
# - Inherit this as the base class.
# - Implement `channel_class` method in your child class.
# - Implement `perform_reply` method in your child class.
# - Implement additional custom logic for your `perform_reply` method.
# - When required override the validation_methods.
# - Use Childclass.new.perform.
######################################
class Base::SendOnChannelService
  pattr_initialize [:message!]

  def perform
    validate_target_channel
    return unless outgoing_message?
    return if invalid_message?
    return if opted_out_message_blocked?

    perform_reply
  end

  private

  delegate :conversation, to: :message
  delegate :contact, :contact_inbox, :inbox, to: :conversation
  delegate :channel, to: :inbox

  def channel_class
    raise 'Overwrite this method in child class'
  end

  def perform_reply
    raise 'Overwrite this method in child class'
  end

  def outgoing_message_originated_from_channel?
    # TODO: we need to refactor this logic as more integrations comes by
    # chatwoot messages won't have source id at the moment
    # TODO: migrate source_ids to external_source_ids and check the source id relevant to specific channel
    message.source_id.present?
  end

  def outgoing_message?
    message.outgoing? || message.template?
  end

  def invalid_message?
    # private notes aren't send to the channels
    # we should also avoid the case of message loops, when outgoing messages are created from channel
    # voice_call bubbles are call status indicators, not deliverable messages
    message.private? || outgoing_message_originated_from_channel? || message.content_type == 'voice_call'
  end

  # Contract (reused by the F2-T3 anti-ban gate service): true when `message` was not
  # authored by a human agent — it was produced by a chatbot flow, an automation rule,
  # a campaign, or its sender is anything other than a User (AgentBot, Captain::Assistant,
  # nil, etc). Doesn't know about opt-out on its own; callers combine it with contact.blocked?.
  def automated_message?
    message.content_attributes['chatbot_id'].present? ||
      Current.executed_by.instance_of?(AutomationRule) ||
      message.additional_attributes['campaign_id'].present? ||
      !message.sender.is_a?(User)
  end

  # Opt-out gate (todos os canais, Fase 2 §2.2): mensagens automatizadas nunca saem para
  # um contato que pediu para sair (contact.blocked?). Mensagem de agente humano continua
  # saindo (decisão consciente, padrão Deskcomm) — só o cruzamento blocked + automated é retido.
  def opted_out_message_blocked?
    return false unless contact.blocked? && automated_message?

    create_opt_out_blocked_activity_message
    true
  end

  def create_opt_out_blocked_activity_message
    content = I18n.t('conversations.activity.opt_out.message_not_sent')
    activity_message_params = {
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :activity,
      content: content
    }
    ::Conversations::ActivityMessageJob.perform_later(conversation, activity_message_params)
  end

  def validate_target_channel
    raise 'Invalid channel service was called' if inbox.channel.class != channel_class
  end
end
