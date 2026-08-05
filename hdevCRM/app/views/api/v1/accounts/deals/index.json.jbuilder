json.payload do
  json.array! @deals do |deal|
    json.partial! 'api/v1/models/deal', formats: [:json], deal: deal
  end
end
