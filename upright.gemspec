require_relative "lib/upright/version"

Gem::Specification.new do |spec|
  spec.name        = "upright"
  spec.version     = Upright::VERSION
  spec.authors     = [ "Lewis Buckley" ]
  spec.email       = [ "lewis@37signals.com" ]
  spec.homepage    = "https://github.com/basecamp/upright"
  spec.summary     = "Synthetic monitoring engine with Playwright and Prometheus metrics"
  spec.description = "A Rails engine for browser-based health probes and uptime monitoring via Prometheus metrics"
  spec.license     = "MIT"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/basecamp/upright"
  spec.metadata["changelog_uri"]   = "https://github.com/basecamp/upright/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib,public}/**/*", "LICENSE.md", "Rakefile", "README.md"]
  end

  spec.required_ruby_version = ">= 3.4"

  # Core dependencies
  spec.add_dependency "cgi"
  spec.add_dependency "rails", ">= 8.0"
  spec.add_dependency "propshaft"
  spec.add_dependency "importmap-rails"
  spec.add_dependency "turbo-rails"
  spec.add_dependency "stimulus-rails"
  spec.add_dependency "solid_queue"
  spec.add_dependency "mission_control-jobs"
  spec.add_dependency "geared_pagination"

  # Probe infrastructure
  spec.add_dependency "frozen_record"
  spec.add_dependency "typhoeus"

  # Playwright (browser automation)
  spec.add_dependency "playwright-ruby-client", "~> #{Upright::PLAYWRIGHT_VERSION}"

  # Observability
  spec.add_dependency "prometheus-api-client"
  spec.add_dependency "yabeda"
  spec.add_dependency "yabeda-prometheus"
  spec.add_dependency "webrick"
  spec.add_dependency "yabeda-puma-plugin"
  spec.add_dependency "prometheus-client"
  spec.add_dependency "opentelemetry-sdk"
  spec.add_dependency "opentelemetry-exporter-otlp"
  spec.add_dependency "opentelemetry-instrumentation-all"

  # Authentication
  spec.add_dependency "omniauth"
  spec.add_dependency "omniauth_openid_connect"
  spec.add_dependency "omniauth-rails_csrf_protection"
end
