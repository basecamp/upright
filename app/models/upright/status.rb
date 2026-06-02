module Upright::Status
  VALUES   = %i[ operational degraded partial_outage major_outage ]
  PRIORITY = VALUES.reverse  # worst first — for picking overall_status across services

  # nil fraction means we have no measurement for the period — distinct from
  # :operational, so we return nil rather than guessing.
  def self.for(uptime_fraction)
    if uptime_fraction
      case uptime_fraction
      when 1.0..  then :operational
      when ...0.5 then :major_outage
      when ...0.9 then :partial_outage
      else             :degraded
      end
    end
  end
end
