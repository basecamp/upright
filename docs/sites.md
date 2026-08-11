# Sites and their roles

Every site runs probes. Two optional roles in `config/sites.yml` say which sites do more than that:

```yaml
shared:
  sites:
    - code: ams
      city: Amsterdam
      country: NL
      geohash: u17982
      provider: digitalocean
      stores_metrics: true
      primary: true

    - code: sfo
      city: San Francisco
      country: US
      geohash: 9q8yy
      provider: hetzner
      stores_metrics: true

    - code: nyc
      city: New York City
      country: US
      geohash: dr5reg
      provider: digitalocean
```

Each site identifies itself with the `SITE_SUBDOMAIN` environment variable, set per host in your Kamal `deploy.yml`. A value naming no site in `sites.yml` refuses to boot, rather than resolving to the first site and quietly labelling that host's data as somewhere else.

## primary

The site serving the app and status hostnames, and running the jobs that write the shared `persistent` database: the daily rollup and the maintenance advance. Those must run in exactly one place, so gate them in `config/recurring.yml`:

```yaml
production:
  aggregate_rollups:
    class: "Upright::Rollups::DailyAggregationJob"
    schedule: every hour at minute 5
```

```erb
<% if Upright.current_site&.primary? %>
```

Declaring two primaries refuses to boot. Declaring none is legal, but that gate is then false everywhere and nothing runs those jobs, so flag exactly one site if you use it. A host gating on something of its own keeps whatever behaviour it already had.

Failing over is moving the flag and deploying, then repointing DNS.

## stores_metrics

Sites running a local Prometheus and Alertmanager. They accept metric writes from every site's collector and serve the `/prometheus` and `/alertmanager` proxies, so losing one leaves the others readable. Probe-only sites serve neither, and 404 those paths rather than proxying to something that isn't there.

Machine callers — collectors writing metrics, jobs reading a peer — authenticate with `Upright.configuration.proxy_token`, which defaults to `PROMETHEUS_OTLP_TOKEN`, instead of an admin session.

These sites are also expected to reach the `persistent` database. Probe-only sites aren't asked to: where they're firewalled off it, a connection attempt hangs rather than being refused, which ties up a worker on every run.

## Health metrics

Every site exports `upright_primary_site`: 1 on the primary, 0 elsewhere. Alerting can then find the primary without hardcoding a site code, and notice when nothing claims the role.

Sites that `stores_metrics` also export `upright_persistent_db_up` and `upright_rollup_last_run_timestamp_seconds`, so both survive losing the primary. The rollup timestamp is read from the newest rollup row rather than stamped when the job finishes, so it isn't reset by a deploy.

`Upright::HealthMetricsJob` refreshes all of them. Schedule it on every site — new installs get it from the generator, existing ones need it adding:

```yaml
production:
  health_metrics:
    class: "Upright::HealthMetricsJob"
    schedule: every minute
```

## Daily rollups

`Upright::Rollups::DailyAggregationJob` writes one row per probe per completed day, which is what the public status page's history reads.

It asks every `stores_metrics` site and takes each probe from whichever one covered that day best. Each holds the whole fleet's series, so each can answer for every probe; they differ only in what they were up to receive. Without that, a day spanning an outage on the site running the rollup would be averaged from a partial window and published as better than it was.

A probe-day whose best coverage falls below `config.rollup_minimum_coverage` (0.9) is left unwritten and counted in `upright_rollup_skipped_probes`. Coverage counts samples of `upright:probe_down_fraction` against `config.rollup_evaluation_interval` (30 seconds), which must match the `interval` on the `upright_recording` rule group.

That series has to emit for healthy probes as well as unhealthy ones for the count to mean anything. The shipped rule does, by falling back to zero when no region is down. If yours predates that, add the fallback or set `config.rollup_minimum_coverage` to 0 to write every day regardless.

Rows are corrected in place, and the job reaches back a week, so a day skipped while a gap was open is rewritten once the gap closes. The coverage guard is what keeps that safe in the other direction: a thin recompute can't overwrite a day already recorded well.
