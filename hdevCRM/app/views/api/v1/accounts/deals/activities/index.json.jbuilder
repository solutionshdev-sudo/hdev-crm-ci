json.payload do
  json.array! @activities do |activity|
    json.id activity.id
    json.activity_type activity.activity_type
    json.data activity.data
    json.created_at activity.created_at.to_i
    json.from_stage activity.from_stage&.name
    json.to_stage activity.to_stage&.name
    if activity.user.present?
      json.user do
        json.id activity.user.id
        json.name activity.user.name
      end
    end
  end
end
