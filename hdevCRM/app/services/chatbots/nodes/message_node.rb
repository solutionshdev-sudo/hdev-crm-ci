class Chatbots::Nodes::MessageNode < Chatbots::Nodes::BaseNode
  def execute
    send_text(data['content'])
    [:continue, next_id]
  end
end
