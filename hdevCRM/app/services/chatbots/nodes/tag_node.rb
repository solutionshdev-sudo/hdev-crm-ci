class Chatbots::Nodes::TagNode < Chatbots::Nodes::BaseNode
  def execute
    add = Array(data['add']).map(&:to_s)
    remove = Array(data['remove']).map(&:to_s)
    labels = (conversation.label_list + add - remove).uniq
    conversation.update_labels(labels)
    [:continue, next_id]
  end
end
