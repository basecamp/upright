module Upright::Public::ServicesHelper
  include LocalTimeHelper

  OVERALL_STATUS_LABELS = {
    operational:    "All Systems Operational",
    degraded:       "Some Systems Degraded",
    partial_outage: "Partial Outage",
    major_outage:   "Major Outage",
    maintenance:    "Service Under Maintenance"
  }

  def overall_status_label(status)
    OVERALL_STATUS_LABELS.fetch(status)
  end

  def maintenance_window_description(maintenance)
    start, finish = maintenance.starts_at, maintenance.ends_at
    same_day = finish && start.to_date == finish.to_date

    if same_day
      "#{start.to_fs(:month_day_at)}–#{finish.to_fs(:clock_zone)}"
    elsif finish
      "#{start.to_fs(:month_day_at)} – #{finish.to_fs(:month_day_at_zone)}"
    else
      start.to_fs(:month_day_at_zone)
    end
  end

  def local_maintenance_window(event)
    if event.ends_at
      safe_join([ local_time(event.starts_at, format: :month_day_at),
                  local_time(event.ends_at, format: :month_day_at_zone) ], " – ")
    else
      local_time(event.starts_at, format: :month_day_at_zone)
    end
  end

  def status_label(status)
    status.to_s.humanize
  end

  def outage_duration_description(started_at:)
    if started_at
      "for #{distance_of_time_in_words(started_at, Time.current)}"
    else
      "for 24 hours+"
    end
  end

  # Stable per-outage id so feed readers treat one ongoing outage as a single
  # item. Falls back to the service code alone when the outage predates the live
  # lookback window and has no known start time.
  def feed_item_guid(outage)
    [ outage.service.code, outage.started_at&.to_i ].compact.join("-")
  end

  def uptime_percentage_label(fractions)
    if fractions.present?
      percentage = fractions.sum.fdiv(fractions.size) * 100
      # A flawless window is a bare "100%". Otherwise round down (so a real
      # outage never reads as 100%) and always show three decimals for a
      # consistent, precise read: "99.990%", "99.800%".
      if percentage >= 100
        number_to_percentage(100, precision: 0)
      else
        number_to_percentage(percentage, precision: 3, round_mode: :down)
      end
    end
  end
end
