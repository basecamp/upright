module Upright::Incidents::AutoReporting
  extend ActiveSupport::Concern

  RESOLVE_DELAY = 5.minutes

  included do
    scope :auto_created, -> { where(auto_created: true) }
  end

  class_methods do
    def report_downtime(now: Time.current)
      degraded_services = Upright::Service.degraded

      degraded_services.each do |entry|
        report_service_downtime(entry, now: now)
      end

      resolve_recovered_incidents(degraded_services, now: now)
    end

    private
      def report_service_downtime(entry, now:)
        service = entry.fetch(:service)
        impact = self::IMPACT_STATUS.key(entry.fetch(:status)).to_s
        incident = reactive.unresolved.for_service(service.code).first

        if incident
          update_reported_incident(incident, impact: impact, now: now)
        else
          incident = new(
            title: "#{service.name} outage",
            impact: impact,
            starts_at: entry[:started_at] || now - Upright::Services::LiveStatus::OUTAGE_LOOKBACK,
            service_codes: [ service.code ],
            auto_created: true,
            auto_service_code: service.code,
            last_seen_down_at: now,
            created_by: "System"
          )
          incident.body = incident.template_body(:down)
          incident.save!
        end
      rescue ActiveRecord::RecordNotUnique
        update_reported_incident(find_by!(auto_service_code: service.code), impact: impact, now: now)
      end

      def resolve_recovered_incidents(degraded_services, now:)
        degraded_codes = degraded_services.map { |entry| entry.fetch(:service).code }

        auto_created.reactive.unresolved.find_each do |incident|
          next if (incident.service_codes & degraded_codes).any?

          if incident.services.any?(&:maintenance_active?)
            incident.update!(recovery_started_at: nil) if incident.recovery_started_at?
            next
          end

          if incident.recovery_started_at.nil?
            incident.update!(recovery_started_at: now)
          elsif incident.recovery_started_at <= now - RESOLVE_DELAY
            incident.record_update(status: "resolved", body: incident.template_body(:back_up))
          end
        end
      end

      def update_reported_incident(incident, impact:, now:)
        attributes = { last_seen_down_at: now, recovery_started_at: nil }
        attributes[:impact] = impact if self::IMPACTS.index(impact) > self::IMPACTS.index(incident.impact)
        incident.update!(attributes)
      end
  end
end
