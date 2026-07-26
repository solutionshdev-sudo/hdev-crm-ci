json.id deal_pipeline.id
json.name deal_pipeline.name
json.description deal_pipeline.description
json.position deal_pipeline.position
json.is_default deal_pipeline.is_default
json.stages do
  json.array! deal_pipeline.deal_stages do |stage|
    json.id stage.id
    json.name stage.name
    json.color stage.color
    json.position stage.position
    json.probability stage.probability
    json.stage_type stage.stage_type
  end
end
