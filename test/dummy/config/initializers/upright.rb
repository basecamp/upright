Upright.configure do |config|
  config.hostname = "upright.localhost"
  config.user_agent = "Upright-Test/1.0"
  config.auth_provider = :static_credentials

  config.public_status_enabled = true

  config.probe_types.register :ping, name: "Ping", icon: "📶"
end
