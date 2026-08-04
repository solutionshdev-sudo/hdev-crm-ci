# Fonte de captação pública de leads (Zapier/n8n/formulários) sobre Channel::Api.
# Cria contato + contact_inbox (idempotente por external_id via
# ContactInboxWithContactBuilder) e, quando vem `mensagem`, conversa + mensagem
# inbound. O card no kanban nasce pela regra de fábrica da Fase 1
# (create_deal em conversation_created) — nenhum código de deal aqui.
#
# Idempotência de retry (mesmo external_id, mesmo payload): se já existe
# conversa ABERTA criada por esse contact_inbox, reusa em vez de abrir outra;
# só acrescenta mensagem se o texto for diferente do último inbound.
class Public::Api::V1::Inboxes::LeadsController < Public::Api::V1::InboxesController
  def create
    @contact_inbox = build_contact_inbox
    @conversation = find_or_create_conversation

    render json: {
      contact_id: @contact_inbox.contact_id,
      conversation_id: @conversation&.display_id,
      source_id: @contact_inbox.source_id
    }
  end

  private

  def build_contact_inbox
    ::ContactInboxWithContactBuilder.new(
      source_id: lead_source_id,
      inbox: @inbox_channel.inbox,
      contact_attributes: contact_attributes
    ).perform
  end

  def lead_source_id
    @lead_source_id ||= params[:external_id].present? ? "lead:#{params[:external_id]}" : SecureRandom.uuid
  end

  def contact_attributes
    {
      name: params[:nome],
      email: params[:email],
      phone_number: params[:telefone],
      additional_attributes: additional_attributes
    }
  end

  def additional_attributes
    attrs = utm_params
    attrs['external_id'] = params[:external_id] if params[:external_id].present?
    attrs
  end

  def utm_params
    params.to_unsafe_h.select { |key, _| key.to_s.start_with?('utm_') }
  end

  def find_or_create_conversation
    return if params[:mensagem].blank?

    open_conversation = @contact_inbox.conversations.where(status: :open).last
    open_conversation ? append_to_conversation(open_conversation) : create_conversation
  end

  def append_to_conversation(conversation)
    last_incoming_content = conversation.messages.incoming.last&.content
    create_incoming_message(conversation) unless last_incoming_content == params[:mensagem]
    conversation
  end

  def create_conversation
    conversation = ::ConversationBuilder.new(params: ActionController::Parameters.new, contact_inbox: @contact_inbox).perform
    create_incoming_message(conversation)
    conversation
  end

  def create_incoming_message(conversation)
    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      sender: @contact_inbox.contact,
      content: params[:mensagem],
      message_type: :incoming
    )
  end
end
