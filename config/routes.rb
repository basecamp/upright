Upright::Engine.routes.draw do
  global_subdomain = ->(req) { Upright.configuration.global_subdomain == req.subdomain }
  site_subdomain   = ->(req) { Upright.configuration.site_subdomains.include?(req.subdomain) }
  public_status    = ->(req) {
    Upright.configuration.public_status_enabled &&
      req.subdomain == Upright.configuration.public_status_subdomain
  }

  constraints global_subdomain do
    root "sites#index", as: :admin_root

    resource :session, only: [ :new, :create ], as: :admin_session
    match "auth/:provider/callback", to: "sessions#create", as: :auth_callback, via: [ :get,  :post ]

    namespace :dashboards do
      resource :uptime, only: :show
      resource :probe_status, only: :show
    end

    scope :framed do
      resource :prometheus,   only: :show, controller: :prometheus_proxy
      resource :alertmanager, only: :show, controller: :alertmanager_proxy
    end

    post "prometheus/api/v1/otlp/v1/metrics", to: "prometheus_proxy#otlp"

    match "prometheus(/*path)",   to: "prometheus_proxy#proxy",   via: :all, as: :prometheus_proxy
    match "alertmanager(/*path)", to: "alertmanager_proxy#proxy", via: :all, as: :alertmanager_proxy
  end

  constraints site_subdomain do
    root "probe_results#index", as: :site_root

    resources :artifacts, only: :show, as: :site_artifacts

    scope :framed do
      resource :jobs, only: :show
    end

    mount MissionControl::Jobs::Engine, at: "/jobs"
  end

  constraints public_status do
    scope module: :public, as: :public do
      root "services#index", as: :services_root
      get "feed", to: "services#index", as: :services_feed, defaults: { format: :rss }
    end
  end

  # Base routes (no subdomain constraint)
  resource :session, only: :destroy
  root "sites#index"
end
