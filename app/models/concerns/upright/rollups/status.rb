module Upright::Rollups::Status
  extend ActiveSupport::Concern

  included do
    enum :status, %i[ operational degraded_performance partial_outage major_outage ], default: :operational
  end

  def uptime_percentage
    if uptime_fraction.present?
      (uptime_fraction * 100).round(4)
    end
  end

  class_methods do
    def status_for(uptime_fraction)
      case uptime_fraction
      when nil    then :operational
      when 1.0..  then :operational
      when ...0.5 then :major_outage
      when ...0.9 then :partial_outage
      else             :degraded_performance
      end
    end
  end
end
