# Changelog

## Unreleased

### Security

- Stop writing a machine token into the generated app. The 0.4 install
  template set `config.proxy_token = ENV.fetch("PROMETHEUS_OTLP_TOKEN",
  "<random>")` in `config/initializers/upright.rb`, so every generated app
  committed a credential that production accepted, and the docs told operators
  to copy it to each site. The template now reads both tokens from the
  environment with no fallback, and `config.proxy_token=` raises with directions.
- Split the token. `PROMETHEUS_OTLP_TOKEN` (`config.otlp_token`) authorizes only
  the OTLP write route; `METRICS_READ_TOKEN` (`config.metrics_read_token`)
  authorizes only `GET` and `HEAD` on the proxies. Outside development and test
  the app refuses to boot when either is missing or both are the same value.
  `Upright::Site#prometheus_client` reads peers with the read token.
- Pin the generated Prometheus accessory to 3.5.5 by image digest, and
  Alertmanager to 0.28.1 by digest. Prometheus 3.0 to 3.5.1 and 3.6 to 3.11.1
  have a stored XSS through metric names and label values (CVE-2026-40179),
  fixed in 3.5.2 and 3.11.2, which the OTLP
  receiver ingests and which executes in the same-origin frame on the admin
  origin with the admin's session. The development compose file moves to
  3.5.5 as well.
- Refuse to deploy without the tokens. The generator adds `PROMETHEUS_OTLP_TOKEN`,
  `METRICS_READ_TOKEN` and `ADMIN_PASSWORD` to `.kamal/secrets` and installs
  `.kamal/hooks/pre-deploy`, which checks the resolved secrets Kamal hands it
  and stops `kamal deploy` before any container is replaced when either token
  is empty or both are the same. Kamal otherwise deploys an empty secret and the
  failure surfaces only at the health check.

### Added

- `config.public_status_json_enabled` serves the public status page as
  read-only v2 status JSON on the public status host, for status widgets,
  aggregators and chat integrations: `/api/v2/summary.json`, `status.json`,
  `components.json`, `incidents.json`, `incidents/unresolved.json`,
  `scheduled-maintenances.json`, `scheduled-maintenances/upcoming.json` and
  `scheduled-maintenances/active.json`. Public services are the components,
  and only incidents and maintenances that affect a public service are
  listed. Responses carry the same 15-second public cache as the pages and
  `Access-Control-Allow-Origin: *`, so pages on other origins can read them. Off
  by default.
- `config.public_status_title` names the public status page, such as
  `"Example Status"`. It is the page's `<title>` (after the incident or service
  name on those pages) and the RSS feed's channel title. It defaults to
  `"Status"`, which changes the feed's channel title from `"Upright Status"`.
- `config.public_status_url` sets the address visitors use for the public
  status pages, such as `"https://status.example.com"`. The RSS feed's channel
  and incident links use it instead of the request's host, which is wrong when a
  CDN in front of the app sends a different Host header. Unset, the feed uses
  the request's host as before.

### Fixed

- Serve the public status pages as HTML whatever the request's `Accept`
  header asks for. A client asking for JSON got a 406 with no `Cache-Control`
  header, and a CDN that caches by URL served that 406 to every visitor until
  its own default expiry. The RSS feed still serves RSS.
- Give not-found responses on the public status pages the same 15-second
  public cache as the pages, and render the app's 404 page for a missing
  incident, so a CDN does not keep them for its default time.
- Load only the stylesheets the public status pages use. The public layout
  called the same `upright_stylesheet_link_tag` as the signed-in UI, which
  globs every engine stylesheet, so a public page fetched all 18 when it uses
  7 of them plus the host's theme; the other eleven (incidents, dashboard,
  forms, tables, ...) matched nothing on the page. The
  layout now calls `upright_public_stylesheet_link_tag`, an explicit list
  followed by `config.public_stylesheets`, and the `.main` padding rule moved
  from `header.css` to `layout.css` so the page keeps its spacing. The admin
  layout is unchanged.
- Serve the Prometheus and Alertmanager UI script bundles through the proxies.
  Rails' forgery protection refuses a JavaScript response to a GET that is not
  an XHR, and the upstream UIs load their bundles with a `<script src>` tag, so
  the proxied page rendered without script and nothing in it worked. The proxy
  action skips that check; the Fetch-Metadata gate already refuses a cross-site
  GET before the action runs, which is what the check guards against.
- Serve the Prometheus and Alertmanager pages of the admin UI to a browser
  arriving from another subdomain. The pages share a controller with the
  proxies, so the proxy's Fetch-Metadata gate refused them as same-site,
  which is how the browser reports a navigation from the app subdomain to a
  site subdomain. The header links there from every app page, so the
  Prometheus and Alertmanager pages answered 403. The gate now applies to the
  `proxy` action only; the pages forward nothing and stay on the session path.
- Report a service down on the status page, and open an automatic incident,
  only when more than half of the sites report its uptime probes down. Live
  status previously ran the site down fraction through the daily-uptime
  thresholds, so one site failing one check out of six showed a partial
  outage and opened a public incident that resolved five minutes later. The
  majority rule is the one `upright:probe_uptime_daily` and the `*ProbeDown`
  alerts already use.

## v0.4.0

### Security

- Release from GitHub Actions instead of a laptop. `bin/release` built the gem
  from whatever was in the working tree, pushed it with a personal RubyGems
  OTP, and only then committed and tagged, so a tag and its gem did not have
  to match. The gemspec globbed the filesystem, which put the ignored
  `config/credentials/development.key` and `test.key` into the public 0.2.0 and
  0.3.0 gems. Treat both keys as disclosed. The gemspec now takes its file list
  from `git ls-files`, a test checks that an ignored key cannot be packaged,
  and `.github/workflows/release.yml` builds each `v*` tag from a clean
  checkout of that commit, checks that the tag matches `Upright::VERSION` and
  is on `main`, publishes through RubyGems trusted publishing with a sigstore
  attestation, and creates the GitHub Release with the gem attached. See
  `RELEASING.md`.
- Stop serving the Playwright Trace Viewer from Upright's origin, and stop
  vendoring it. The viewer serialised a trace's tags and attributes into
  `text/html` on the admin origin, so a crafted trace ZIP executed script there
  and could read admin pages and CSRF tokens. Traces are now download-only
  linked to the viewer at `config.trace_viewer_url`, which defaults to upstream's
  hosted `https://trace.playwright.dev` and can be pointed at a viewer you host
  or set to nil for download-only traces (`npx playwright show-trace`). A URL
  under `config.hostname` is refused. The viewer reads the trace through
  `Upright::TracesController`, which sends `Access-Control-Allow-Origin` for that
  viewer's origin alone and authorizes the request with a purpose-scoped signed
  id that expires after 24 hours instead of the admin session. Following a trace
  link therefore hands the viewer's origin a URL it can read for 24 hours.
- Fix an authenticated SSRF through the Prometheus/Alertmanager proxies: a
  protocol-relative path (`//host`) could retarget the upstream request at an
  arbitrary host (RFC1918, the Docker network, cloud metadata). The upstream URL
  is now built structurally — scheme, host and port always come from the
  configured upstream — and the forwarded path is validated, with a
  `faraday >= 2.14.3` floor (CVE-2026-25765).
- Refuse cross-site requests to the metrics proxies on the session-cookie path
  via a Fetch-Metadata / Origin gate; only same-origin and user-initiated (`none`)
  requests are honoured, and missing provenance headers fail closed
  (CVE-2026-67990).
- Require a POST with a valid authenticity token on the `static_credentials`
  sign-in callback, and fail closed when `ADMIN_PASSWORD` is unset instead of
  shipping a default password (CVE-2026-67993).
- Scope the session cookie to the configured hostname rather than its registrable
  parent, so a sibling domain can't be handed the admin session.
- Redact `Authorization`/`Cookie` credentials from probe logs, store HTTP probe
  bodies as inert size-capped artifacts, don't record Playwright traces for
  authenticated probes (and drop snapshots/signed-blob-URL logging for the rest),
  and scope artifact downloads to probe results.
- Restrict the public status page to incidents affecting a public-facing service,
  and harden the generated deploy defaults (drop the OTEL Docker-socket mount,
  bind services to loopback, ship a random proxy token and a CSP template).
- Update Active Storage to close an arbitrary-file-read → RCE (rails 8.1.3.1,
  CVE-2026-66066).

### Upgrading

Some of the security fixes live in generated, host-owned config that a gem
upgrade does not rewrite. Existing installs should apply these by hand:

- `config/initializers/omniauth.rb`: fail closed when `ADMIN_PASSWORD` is unset
  instead of `ENV.fetch("ADMIN_PASSWORD", "upright")`, so the well-known default
  password is removed (compare against the current install template).
- `config/recurring.yml`: existing installs need these entries, which the
  install generator now writes for new ones. Compare against the template in
  `lib/generators/upright/install/templates/recurring.yml`:
  - `sweep_playwright_videos` (`Upright::PlaywrightVideoSweepJob`, hourly), so
    stranded recordings from a crashed run are still cleaned up.
  - `health_metrics` (`Upright::HealthMetricsJob`, every minute), which exports
    `upright_primary_site`, `upright_persistent_db_up` and
    `upright_rollup_last_run_timestamp_seconds`.
  - Only with the public status page enabled: `aggregate_rollups`
    (`Upright::Rollups::DailyAggregationJob`, hourly), which writes the daily
    uptime the page shows; `report_incidents` (`Upright::IncidentReporterJob`,
    every 30 seconds), which opens and resolves incidents from probe results;
    and `advance_maintenances` (`Upright::MaintenanceAdvanceJob`, every 15
    seconds), which starts and completes scheduled maintenance windows on time.
- `config/database.yml`: add a `persistent` database for rollups, incidents and
  maintenance windows, with `migrations_paths` pointing at the gem's
  `db/persistent_migrate`; the install generator now writes it for new apps.
  Status history lives there so it survives a site's probe data being purged.

`UPGRADING.md` walks through every step from 0.3 to 0.4 with the config to
copy.
- `config/initializers/content_security_policy.rb`: adopt the recommended policy
  from the install template if you don't already enforce a CSP.
- `config/initializers/upright.rb`: trace artifacts now link to
  `https://trace.playwright.dev` by default. Set `config.trace_viewer_url` to a
  viewer you host, or to nil, if you don't want trace URLs handed to that origin.

### Changed

- Publish Prometheus and Alertmanager on loopback ports instead of `network_mode: host` in the generated and dummy `docker-compose.yml`, and scrape the app through `host.docker.internal`, so the development services work on macOS and Windows Docker Desktop as well as Linux (#54)
- Open, escalate and resolve incidents automatically from probe results: a service that stops passing gets an incident with a fixed "investigating" update, its impact follows the probes, and it resolves after five minutes of continuous recovery. `Upright::IncidentReporterJob` runs from `recurring.yml`; incidents also get operator shortcuts and a public per-service history (#137)
- Convert timestamps on the public status page to the visitor's time zone. The page now loads a JavaScript entry point of its own, `upright/public`, which carries only local-time; the admin app's modules are preloaded for the `application` entry point alone (#141)
- Compute a service's live status and daily uptime from its HTTP probes only. A service that wants other types counted lists them under `uptime_probe_types` in services.yml (`[http, playwright]`); a type not registered with `config.probe_types` raises. Types left out are still probed, rolled up and alerted on; this keeps a 15-minute Playwright probe from recording its whole interval as downtime on the status page. Rollups written before probe types were recorded keep counting (#138)
- Roll up daily uptime from every `stores_metrics` site, preferring the best-covered instance per probe; skip and report probe-days below `config.rollup_minimum_coverage` instead of averaging a gappy window; correct rollups in place and backfill a week (#121). `upright:probe_down_fraction` now falls back to zero when no region is down, which the coverage count depends on; rules predating this need the same fallback, or `config.rollup_minimum_coverage = 0`
- Add public status pages: live status, 90-day history, and an RSS feed (#79)
- Use OpenStreetMap tiles for the sites map in both colour schemes instead of CARTO's dark tiles, which need an API key; the map's dark mode is now a CSS filter over the same tiles. The install generator's CSP template no longer allows `basemaps.cartocdn.com`
- Export `upright_primary_site`, `upright_persistent_db_up`, and `upright_rollup_last_run_timestamp_seconds` for failover alerting; sites declare `primary: true`, and existing installs need `Upright::HealthMetricsJob` adding to `recurring.yml` (#116)
- Add incidents and scheduled maintenance, with a public timeline and impact banner (#102)
- Record who created and updated each incident (#105)
- Let host apps override the public status page's stylesheets and views (#109)
- Split rollups into a `persistent` database so status history outlives a site's probe data — host apps need a `persistent` connection in `database.yml` (#87)
- Serve the Prometheus and Alertmanager proxies on any site declaring `stores_metrics: true` rather than the app subdomain alone, and accept a token in place of an admin session (#114)
- Scope Prometheus queries by environment, so staging stops reporting production data (#95)
- Use HTTPS and secure cookies in every deployed environment, not just production (#89)
- Show an environment badge in the header outside production (#90)
- Make the services definition path env-overridable (#97)
- Launch Playwright directly instead of through a remote server (#55)
- Carry `alert_severity` through the generated alert rules so routing keeps the label (#58)
- Give probe result durations sub-second precision (#96)
- Make service descriptions optional, and improve the uptime tooltips (#99)
- Show uptime to three decimals; never round an outage up to 100% (#98)
- Purge stale probe results without enqueuing a job per attachment (#69)

## v0.3.0

- Allow host apps to register custom probe types via `config.probe_types.register` (#42)
- Make probe result stale cleanup thresholds configurable (#44)
- Add configurable alert severity per probe (#35)
- Retain probe failures for 30 days with a 20,000 cap (#38)
- Add clickable uptime days to filter probe results by date (#39)
- Allow connection reuse for proxied HTTP requests (#34)
- Add Solid Queue setup to install generator (#29)
- Fix links on uptime page
- Fix session fixation on login

## v0.2.0

Initial open source release.

- Playwright, HTTP, SMTP, and Traceroute probes
- Multi-site support with staggered scheduling
- Uptime and probe status dashboards
- Prometheus metrics and AlertManager integration
- OpenTelemetry tracing and logging
- OmniAuth authentication with OIDC support
- Kamal deployment templates
- Rails install generator
