class Chatbots::Nodes::HandoffNode < Chatbots::Nodes::BaseNode
  def execute
    send_text(data['message']) if data['message'].present?
    assign
    add_note
    # bot_handoff! reabre a conversa e dispara CONVERSATION_BOT_HANDOFF — o
    # resto do sistema (fila, notificações, IA) já entende esse evento.
    conversation.bot_handoff!
    [:halt, :handed_off]
  end

  private

  def assign
    case data['assign_to']
    when 'team'
      team = conversation.account.teams.find_by(id: data['team_id'])
      conversation.update!(team: team) if team
    when 'agent'
      agent = conversation.account.users.find_by(id: data['agent_id'])
      conversation.update!(assignee: agent) if agent
    end
  end

  def add_note
    return if data['note'].blank?

    params = {
      content: interpolate(data['note']),
      private: true,
      content_attributes: { chatbot_id: chatbot.id, node_id: node['id'] }
    }
    Messages::MessageBuilder.new(nil, conversation, params).perform
  end
end
