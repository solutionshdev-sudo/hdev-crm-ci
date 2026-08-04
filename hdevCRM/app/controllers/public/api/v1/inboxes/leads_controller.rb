# Fonte de captação pública de leads (Zapier/n8n/formulários) sobre Channel::Api.
# Cria contato + contact_inbox (idempotente por external_id via
# ContactInboxWithContactBuilder) e, quando vem `mensagem`, conversa + mensagem
# inbound. O card no kanban nasce pela regra de fábrica da Fase 1
# (create_deal em conversation_created) — nenhum código de deal aqui.
#
# Idempotência de retry (mesmo external_id, mesmo payload): reusa a conversa
# reaproveitável mais recente desse contact_inbox (qualquer status que não
# seja `resolved` — cobre tanto `open` quanto `pending`, caso do bot/SLA que
# muda o status default na criação) e só acrescenta mensagem se o texto for
# diferente do último inbound. A mesma checagem de duplicidade roda mesmo
# quando é o ConversationBuilder (não este método) quem devolve a conversa já
# existente — caso do inbox com `lock_to_single_conversation`.
class Public::Api::V1::Inboxes::LeadsController < Public::Api::V1::InboxesController
  # Só servem pra contacts/conversations aninhados de verdade (:contact_id,
  # :conversation_id na rota) — aqui não existem, mas os before_actions do pai
  # também leem do BODY (params[:contact_id]/params[:conversation_id]), então
  # sem o skip um lead malicioso/errado nesses campos derruba a request com
  # 500 (contact_inbox nil) ou 404 indevido antes de chegar em #create.
  skip_before_action :set_contact_inbox, :set_conversation

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

  # Filtro escalar: chaves compostas como `nome[a]=b` chegam como
  # ActionController::Parameters e são descartadas pelo `permit` (viram nil),
  # em vez de estourar NoMethodError lá na frente (ex.: Contact#truncate) e
  # devolver 500 público.
  def permitted_params
    @permitted_params ||= params.permit(:nome, :email, :telefone, :mensagem, :external_id)
  end

  def build_contact_inbox
    ::ContactInboxWithContactBuilder.new(
      source_id: lead_source_id,
      inbox: @inbox_channel.inbox,
      contact_attributes: contact_attributes
    ).perform
  end

  def lead_source_id
    @lead_source_id ||= permitted_params[:external_id].present? ? "lead:#{permitted_params[:external_id]}" : SecureRandom.uuid
  end

  def contact_attributes
    {
      name: permitted_params[:nome],
      email: permitted_params[:email],
      phone_number: permitted_params[:telefone],
      additional_attributes: additional_attributes
    }
  end

  def additional_attributes
    attrs = utm_params
    attrs['external_id'] = permitted_params[:external_id] if permitted_params[:external_id].present?
    attrs
  end

  # Só aceita valor String pra cada `utm_*` — `utm_source[a]=b` vira Parameters
  # aninhado no `to_unsafe_h`, e um jsonb com esse shape é ruído no additional_attributes
  # (e um vetor de payload estranho pro resto do app que lê essas chaves como texto).
  def utm_params
    params.to_unsafe_h.select { |key, value| key.to_s.start_with?('utm_') && value.is_a?(String) }
  end

  def find_or_create_conversation
    return if permitted_params[:mensagem].blank?

    conversation = reusable_conversation || build_conversation
    append_message_unless_duplicate(conversation)
    conversation
  end

  def reusable_conversation
    @contact_inbox.conversations.where.not(status: :resolved).last
  end

  def build_conversation
    ::ConversationBuilder.new(params: ActionController::Parameters.new, contact_inbox: @contact_inbox).perform
  end

  def append_message_unless_duplicate(conversation)
    last_incoming_content = conversation.messages.incoming.last&.content
    create_incoming_message(conversation) unless last_incoming_content == permitted_params[:mensagem]
  end

  def create_incoming_message(conversation)
    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      sender: @contact_inbox.contact,
      content: permitted_params[:mensagem],
      message_type: :incoming
    )
  end
end
