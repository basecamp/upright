# Upgrading Upright

## From 0.3 to 0.4

0.4 adds an optional public status page with incidents and scheduled
maintenance, a second database for the data behind them, several security fixes
to generated config, and a Playwright that runs in-process instead of against a
browser server. The gem upgrade does none of the host-app changes for you.
Steps 1 to 9 apply to every install. Step 10 is only for installs that turn the
status page on. Check the result at the end.

### 1. Update the gem

```sh
bundle update upright
```

This also raises `faraday` to at least 2.14.3, which closes an SSRF in the
Prometheus and Alertmanager proxies.

### 2. Add the persistent database

Rollups, incidents and maintenance windows live in a database of their own so
status history survives a site's probe data being purged. Its migrations ship
with the gem. Add a `persistent` entry next to `primary` and `queue` in
`config/database.yml` for every environment, and point its migrations at the
installed gem:

```yaml
development:
  primary:
    <<: *default
    database: storage/development.sqlite3
  persistent:
    <<: *default
    database: storage/development_persistent.sqlite3
    migrations_paths: <%= Gem.loaded_specs["upright"].gem_dir %>/db/persistent_migrate
  queue:
    <<: *default
    database: storage/development_queue.sqlite3
    migrations_paths: db/queue_migrate
```

For MySQL or PostgreSQL, give `persistent` its own database name. If you run
more than one site, they should share one persistent database, replicated if
you need it to survive a site.

Then create and migrate everything. This also runs a new `primary` migration
that gives probe result durations sub-second precision:

```sh
bin/rails db:prepare
```

### 3. Schedule the new housekeeping and health jobs

Add these to `config/recurring.yml` under each deployed environment. They match
the install generator's template.

```yaml
  sweep_playwright_videos:
    class: "Upright::PlaywrightVideoSweepJob"
    schedule: every hour at minute 45

  health_metrics:
    class: "Upright::HealthMetricsJob"
    schedule: every minute
```

`sweep_playwright_videos` removes recordings a crashed probe run leaves
behind. `health_metrics` exports `upright_primary_site`,
`upright_persistent_db_up` and `upright_rollup_last_run_timestamp_seconds` for
failover alerting. The status page's jobs are in step 10.

### 4. Mark the sites that hold metrics

In `config/sites.yml`, add `stores_metrics: true` to every site that runs
Prometheus, and `primary: true` to the one whose data is authoritative:

```yaml
    - code: ams
      city: Amsterdam
      country: NL
      geohash: u17982
      stores_metrics: true
      primary: true
```

The Prometheus and Alertmanager proxies are served on every `stores_metrics`
site, not only the app subdomain, and rollups read from all of them.

### 5. Update the initializer

Compare `config/initializers/upright.rb` with the install generator's template
and add:

- `config.proxy_token`. A token that collectors writing metrics and peer sites
  reading the proxies present instead of an admin session. Every site must use
  the same value. The template reads it from `PROMETHEUS_OTLP_TOKEN`; add that
  as a Kamal secret.
- `config.playwright_cli_path` replaces `config.playwright_server_url`. Probes
  now launch Playwright directly. Remove the old setting.
- `config.trace_viewer_url` if you do not want trace links to open in
  `https://trace.playwright.dev`. Point it at a viewer you host, or set it to
  nil to make traces download-only.

### 6. Regenerate the Prometheus recording rules

The recording rules now carry a `probe_service` label so the status page and
rollups can read status per service, and `upright:probe_down_fraction` falls
back to zero when no region is down. Copy
`lib/generators/upright/install/templates/upright.rules.yml` from the gem over
`config/prometheus/rules/upright.rules.yml`, keeping any alerts of your own,
and redeploy Prometheus. The fallback matters once the status page's
`aggregate_rollups` job runs: without it the coverage check skips healthy days.
If you cannot update the rules yet, set `config.rollup_minimum_coverage = 0`.

### 7. Fail closed on the admin password

`config/initializers/omniauth.rb` used to default the admin password to
`upright`. Replace the credentials line so the static provider is left
unconfigured when `ADMIN_PASSWORD` is unset:

```ruby
admin_password = ENV["ADMIN_PASSWORD"].presence
# ...
credentials: admin_password ? { "admin" => admin_password } : {}
```

Add `ADMIN_PASSWORD` to your Kamal secrets. Without it nobody can sign in with
the static provider, which is the intended behaviour.

### 8. Run Playwright in the app container

Probes launch Playwright directly, so the browser must be installed where the
jobs run.

- Remove the `playwright` accessory from `config/deploy.yml` and the
  Playwright service from `docker-compose.yml`.
- Update the `Dockerfile` from the generator template. It installs Node, then
  `playwright` at `Upright::PLAYWRIGHT_VERSION` with the Chromium browser, in a
  layer that is cached across code-only deploys.
- In development, run `npx playwright install chromium` once.

### 9. Harden the deploy config

From the `config/deploy.yml` template:

- The OpenTelemetry collector no longer mounts the Docker socket or the host's
  container logs, no longer runs as root, and is pinned by image digest. Remove
  the `volumes` and `options` blocks from the `otel_collector` accessory.
- Prometheus no longer publishes a port and no longer enables
  `--web.enable-lifecycle`. The app reaches it over the Docker network and
  proxies it.
- The collector's OTLP receiver listens on the Docker network only; see the
  comment in the `otel_collector.yml` template.

#### Content Security Policy (optional)

`config/initializers/content_security_policy.rb` from the template covers the
engine's CDN dependencies, the OpenStreetMap tiles the sites map now uses, and
the trace viewer. Merge it into your policy if you enforce one. The old
`basemaps.cartocdn.com` host is no longer needed.

### 10. Only if you enable the public status page

The status page is off by default. Everything in this step can be skipped if
you leave it off.

Turn it on in `config/initializers/upright.rb`:

```ruby
config.public_status_enabled = true
config.public_status_custom_domains = [ "status.example.com" ]
```

Add the page's hostname to the proxy hosts in `config/deploy.yml` and to DNS.
`config.public_stylesheets` lets you override its stylesheets and views.
`config.rollup_minimum_coverage` skips a probe-day with too few samples rather
than averaging it; the default is fine to start with.

Schedule the jobs that build its history, open its incidents and run its
maintenance windows:

```yaml
  aggregate_rollups:
    class: "Upright::Rollups::DailyAggregationJob"
    schedule: every hour at minute 5

  report_incidents:
    class: "Upright::IncidentReporterJob"
    schedule: "*/30 * * * * *"

  advance_maintenances:
    class: "Upright::MaintenanceAdvanceJob"
    schedule: "*/15 * * * * *"
```

`aggregate_rollups` writes the daily uptime the page shows and backfills a
week on first run. `report_incidents` opens an incident when a public service
stops passing its probes and resolves it after five minutes of recovery.
`advance_maintenances` starts and completes scheduled maintenance windows on
time.

Then group probes into the services the page lists. Create `config/services.yml` and add a `service:` key to each probe definition
in `probes/*.yml` naming the service it belongs to:

```yaml
# config/services.yml
- code: app
  name: Example App
  url: app.example.com
  public: true
```

- `public: true` shows the service on the status page. Others stay internal.
- `uptime_probe_types` lists the probe types that decide live status and
  uptime. The default is `[http]`. Add `playwright` to count those runs too; a
  probe on a 15-minute interval records its whole interval as downtime when one
  run fails.
- `incident_updates` overrides the automatic incident text per service, with
  keys `down`, `investigating` and `back_up`.

Set `config.services_path` if the file lives elsewhere. Order in the file is
the display order.

### 11. Check the result

```sh
bin/rails runner 'puts Upright::PersistentRecord.up?'   # true
bin/rails runner 'puts Upright::Service.count'          # 0 unless you did step 10
```

After deploying, confirm on each site that `upright_primary_site` and
`upright_persistent_db_up` are present in Prometheus, that the status page
answers on its hostname if you enabled it, and that a probe run records a
result. The first daily uptime bars appear after `aggregate_rollups` has run
and a week of history has been backfilled.
