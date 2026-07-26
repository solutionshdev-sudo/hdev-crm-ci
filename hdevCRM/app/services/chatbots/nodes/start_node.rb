class Chatbots::Nodes::StartNode < Chatbots::Nodes::BaseNode
  def execute
    [:continue, next_id]
  end
end
