json.payload do
  json.array! @sessions do |session|
    json.id session.id
    json.conversation_id session.conversation_id
    json.status session.status
    json.current_node_id session.current_node_id
    json.variables session.variables
    json.last_error session.last_error
    json.created_at session.created_at
    json.updated_at session.updated_at
  end
end
