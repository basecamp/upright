# Changelog

## v0.3.1

Security backport release for v0.3.0 installs.

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
  parent, so a sibling domain can't be handed the admin session, and mark it
  httponly (F-08).

### Upgrading

Everyone signs in again once: the session cookie key changed so a 0.3.0 cookie
scoped to the registrable parent can't linger usable after the scope tightened
(F-08).

The `static_credentials` fail-closed password fix lives in the install template,
which a gem upgrade does not copy back over an existing app. Existing v0.3.0
installs must update `config/initializers/omniauth.rb` by hand so an unset
`ADMIN_PASSWORD` no longer falls back to the well-known `upright` default — set
`ADMIN_PASSWORD`, or mirror the current template (which drops the default). The
SSRF and proxy/login CSRF fixes are in engine code and apply automatically.

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
