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

  # The manifest is the git index, not a filesystem glob. A glob packages whatever
  # is present in the working tree, which is how the ignored
  # config/credentials/*.key files reached the public 0.2.0 and 0.3.0 gems.
  # test/packaging_test.rb checks this.
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true)
  end.grep(%r{\A(?:app|config|db|lib|public)/|\A(?:LICENSE\.md|Rakefile|README\.md)\z})

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
  spec.add_dependency "local_time"

  # Probe infrastructure
  spec.add_dependency "frozen_record"
  spec.add_dependency "typhoeus"

  # HTTP client for the metrics proxies. Floor at 2.14.3: earlier releases let a
  # protocol-relative path (`//host`) override the upstream authority via
  # URI#merge, an SSRF through the proxies (CVE-2026-25765 / -33637 / -54297).
  spec.add_dependency "faraday", ">= 2.14.3"

  # Playwright (browser automation)
  # Keep in sync with Upright::PLAYWRIGHT_VERSION in lib/upright/version.rb
  spec.add_dependency "playwright-ruby-client", "~> 1.59.0"

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
