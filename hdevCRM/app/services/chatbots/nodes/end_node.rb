class Chatbots::Nodes::EndNode < Chatbots::Nodes::BaseNode
  def execute
    send_text(data['message']) if data['message'].present?
    if data['resolve_conversation']
      conversation.update!(status: :resolved)
    else
      # sem resolver: reabre pra fila humana em vez de deixar pending invisível
      conversation.bot_handoff!
    end
    [:halt, :completed]
  end
end
