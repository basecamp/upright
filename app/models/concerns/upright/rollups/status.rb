module Upright::Rollups::Status
  extend ActiveSupport::Concern

  STATUSES = [ :operational, :degraded_performance, :partial_outage, :major_outage ]

  included do
    enum :status, STATUSES, default: :operational
  end

  def uptime_percentage
    return nil if uptime_fraction.nil?
    (uptime_fraction * 100).round(4)
  end

  class_methods do
    def status_for(uptime_fraction)
      return :operational if uptime_fraction.nil? || uptime_fraction >= 1.0

      case uptime_fraction
      when ...0.5 then :major_outage
      when ...0.9 then :partial_outage
      else :degraded_performance
      end
    end
  end
end
