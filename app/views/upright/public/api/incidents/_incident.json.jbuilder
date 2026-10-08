json.id incident.id.to_s
json.name incident.title
json.status incident.status
json.impact incident.impact
json.created_at api_timestamp(incident.created_at)
json.updated_at api_timestamp(incident.updated_at)
json.started_at api_timestamp(incident.starts_at)
json.monitoring_at api_timestamp(monitoring_at(incident))
json.resolved_at api_timestamp(incident.resolved_at)
json.shortlink "#{public_status_base_url}/incidents/#{incident.id}"
json.page_id Upright.configuration.service_name

json.incident_updates incident.updates do |update|
  json.partial! "upright/public/api/incidents/incident_update", incident: incident, update: update
end

json.components incident.public_services do |service|
  json.partial! "upright/public/api/components/component", service: service, position: nil
end

if incident.maintenance?
  json.scheduled_for api_timestamp(incident.starts_at)
  json.scheduled_until api_timestamp(incident.ends_at)
end
