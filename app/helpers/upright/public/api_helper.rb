module Upright::Public::ApiHelper
  STATUS_INDICATORS = { operational: "none", degraded: "minor", partial_outage: "major", major_outage: "critical", maintenance: "maintenance" }
  COMPONENT_STATUSES = { operational: "operational", degraded: "degraded_performance", partial_outage: "partial_outage", major_outage: "major_outage" }

  def status_indicator(status)
    STATUS_INDICATORS.fetch(status)
  end

  def component_status(service)
    service.maintenance_active? ? "under_maintenance" : COMPONENT_STATUSES.fetch(service.live_status)
  end

  def monitoring_at(incident)
    incident.updates.select { |update| update.status == "monitoring" }.min_by(&:created_at)&.created_at
  end

  def api_timestamp(time)
    time&.utc&.iso8601(3)
  end
end
