# Changelog

## [Unreleased]

### Added

- Playwright probes now collect INP (Interaction to Next Paint) as the responsiveness Core Web Vital. INP replaced FID in March 2024 ([web.dev](https://web.dev/blog/inp-cwv-launch)); FID was fully removed from Chrome tools by September 2024. INP is reported as `browser.performance.inp` in OpenTelemetry spans.

### Deprecated

- FID (First Input Delay) is still collected as `browser.performance.fid` for backward compatibility but deprecated; use INP for responsiveness monitoring going forward.

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
