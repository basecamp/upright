json.id update.id.to_s
json.status update.status
json.body update.body
json.incident_id incident.id.to_s
json.created_at api_timestamp(update.created_at)
json.updated_at api_timestamp(update.created_at)
json.display_at api_timestamp(update.created_at)
json.affected_components nil
