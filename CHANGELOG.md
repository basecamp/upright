# Changelog

## Unreleased

### Security

- Fix an authenticated SSRF through the Prometheus/Alertmanager proxies: a
  protocol-relative path (`//host`) could retarget the upstream request at an
  arbitrary host (RFC1918, the Docker network, cloud metadata). Forwarded paths
  are now validated and the resolved host is re-checked, with a `faraday >= 2.14.3`
  floor (CVE-2026-25765).
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
  bodies as inert size-capped artifacts, stop recording Playwright snapshots and
  logging signed blob URLs, and scope artifact downloads to probe results.
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
- `config/recurring.yml`: add the `sweep_playwright_videos` entry
  (`class: "Upright::PlaywrightVideoSweepJob"`) so stranded recordings from a
  crashed run are still cleaned up.
- `config/initializers/content_security_policy.rb`: adopt the recommended policy
  from the install template if you don't already enforce a CSP.

### Changed

- Add public status pages: live status, 90-day history, and an RSS feed (#79)
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
