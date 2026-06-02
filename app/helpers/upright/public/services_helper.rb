module Upright::Public::ServicesHelper
  OVERALL_STATUS_LABELS = {
    operational:    "All Systems Operational",
    degraded:       "Some Systems Degraded",
    partial_outage: "Partial Outage",
    major_outage:   "Major Outage"
  }

  def overall_status_label(status)
    OVERALL_STATUS_LABELS.fetch(status)
  end

  def status_label(status)
    status.to_s.humanize
  end

  def outage_duration_phrase(started_at:)
    if started_at
      "for #{distance_of_time_in_words(started_at, Time.current)}"
    else
      "for 24 hours+"
    end
  end

  # Stable per-outage id so feed readers treat one ongoing outage as a single
  # item. Falls back to the service code alone when the outage predates the live
  # lookback window and has no known start time.
  def feed_item_guid(issue)
    [ issue[:service].code, issue[:started_at]&.to_i ].compact.join("-")
  end

  def average_uptime_percentage(fractions)
    if fractions.present?
      (fractions.sum.to_f / fractions.size) * 100
    end
  end
end
