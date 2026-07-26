class Chatbots::Nodes::EndNode < Chatbots::Nodes::BaseNode
  def execute
    send_text(data['message']) if data['message'].present?
    conversation.update!(status: :resolved) if data['resolve_conversation']
    [:halt, :completed]
  end
end
