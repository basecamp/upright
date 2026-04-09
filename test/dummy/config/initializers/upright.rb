Upright.configure do |config|
  config.hostname = "upright.localhost"
  config.user_agent = "Upright-Test/1.0"
  config.auth_provider = :static_credentials

  config.probe_types.register :ping, name: "Ping", icon: "📶"
end
