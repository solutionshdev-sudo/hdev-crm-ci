json.id deal.id
json.title deal.title
json.description deal.description
json.value deal.value
json.currency deal.currency
json.status deal.status
json.position deal.position
json.expected_close_on deal.expected_close_on
json.closed_at deal.closed_at
json.lost_reason deal.lost_reason
json.custom_attributes deal.custom_attributes
json.account_id deal.account_id
json.deal_pipeline_id deal.deal_pipeline_id
json.deal_stage_id deal.deal_stage_id
json.conversation_id deal.conversation_id
json.created_at deal.created_at
json.updated_at deal.updated_at

json.contact do
  json.id deal.contact.id
  json.name deal.contact.name
  json.email deal.contact.email
  json.phone_number deal.contact.phone_number
  json.thumbnail deal.contact.avatar_url
end

if deal.assignee.present?
  json.assignee do
    json.partial! 'api/v1/models/agent', formats: [:json], resource: deal.assignee
  end
end
