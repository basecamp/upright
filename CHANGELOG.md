# Changelog

## Unreleased

- Add public status pages: live status, 90-day history, and an RSS feed (#79)
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
