class Upright::Rollups::ProbeUptime < Data.define(:probe_name, :probe_type, :probe_target, :probe_service, :uptime_fraction, :coverage_fraction)
  def probe_key
    [ probe_name, probe_type, probe_target ]
  end

  def covered?
    coverage_fraction >= Upright.configuration.rollup_minimum_coverage
  end
end
