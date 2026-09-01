class Upright::Service::Outage < Data.define(:service, :status, :started_at)
  IMPACT_BY_STATUS = {
    degraded: "minor",
    partial_outage: "major",
    major_outage: "critical"
  }

  def impact
    IMPACT_BY_STATUS.fetch(status)
  end

  def started_at_or_lookback(observed_at:)
    started_at || observed_at - Upright::Services::LiveStatus::OUTAGE_LOOKBACK
  end
end
