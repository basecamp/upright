# Set ADMIN_PASSWORD to enable the built-in admin login. When it is unset the
# static credential is left unconfigured (fail closed) so the app never ships a
# well-known default password. Change the username/credentials below to suit, or
# switch to an external provider (e.g. OpenID Connect) via config.auth_provider.

admin_password = ENV["ADMIN_PASSWORD"].presence

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :static_credentials,
    title: "Sign In",
    credentials: admin_password ? { "admin" => admin_password } : {}
end
