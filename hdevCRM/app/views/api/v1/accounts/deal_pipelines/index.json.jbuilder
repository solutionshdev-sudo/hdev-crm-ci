json.payload do
  json.array! @pipelines do |pipeline|
    json.partial! 'api/v1/models/deal_pipeline', formats: [:json], deal_pipeline: pipeline
  end
end
