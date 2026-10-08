json.page do
  json.id Upright.configuration.service_name
  json.name Upright.configuration.public_status_title
  json.url public_status_base_url
  json.time_zone "Etc/UTC"
  json.updated_at api_timestamp(Time.current)
end
