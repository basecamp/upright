module Upright::Incidents::AutoReporting
  extend ActiveSupport::Concern

  RESOLVE_DELAY = 5.minutes

  included do
    scope :auto_created, -> { where(auto_created: true) }
  end

  class_methods do
    def report_downtime(now: Time.current)
      outages = Upright::Service.degraded

      outages.each { |outage| report_outage(outage, observed_at: now) }
      observe_recoveries(excluding: outages.map(&:service), observed_at: now)
    end

    private
      def report_outage(outage, observed_at:)
        if incident = reactive.unresolved.for_service(outage.service.code).first
          incident.observe_downtime(outage, at: observed_at)
        else
          open_automatically(outage, at: observed_at)
        end
      rescue ActiveRecord::RecordNotUnique
        joins(:automatic_report)
          .find_by!(upright_incident_automatic_reports: { service_code: outage.service.code })
          .observe_downtime(outage, at: observed_at)
      end

      def open_automatically(outage, at:)
        new(
          title: "#{outage.service.name} outage",
          impact: outage.impact,
          starts_at: outage.started_at_or_lookback(observed_at: at),
          last_seen_down_at: at,
          created_by: "System"
        ).tap do |incident|
          incident.automatically_affect(outage.service)
          incident.body = incident.update_body_for(:down)
          incident.save!
        end
      end

      def observe_recoveries(excluding:, observed_at:)
        degraded_codes = excluding.map(&:code)

        auto_created.reactive.unresolved.find_each do |incident|
          incident.observe_recovery(at: observed_at) unless (incident.service_codes & degraded_codes).any?
        end
      end
  end

  def automatically_affect(service)
    self.auto_created = true
    self.service_codes = [ service.code ]
    build_automatic_report(service_code: service.code)
  end

  def observe_downtime(outage, at:)
    self.last_seen_down_at = at
    self.recovery_started_at = nil
    escalate_to(outage.impact)
    save!
  end

  def observe_recovery(at:)
    if services.any?(&:maintenance_active?)
      pause_recovery
    elsif recovery_started_at.nil?
      update!(recovery_started_at: at)
    elsif recovery_started_at <= at - RESOLVE_DELAY
      resolve_automatically(at: at)
    end
  end

  private
    def escalate_to(new_impact)
      self.impact = new_impact if self.class::IMPACTS.index(new_impact) > self.class::IMPACTS.index(impact)
    end

    def pause_recovery
      update!(recovery_started_at: nil) if recovery_started_at?
    end

    def resolve_automatically(at:)
      record_update({ status: "resolved", body: update_body_for(:back_up) }, recorded_at: at)
    end

    def after_recording_terminal_status
      automatic_report&.destroy!
    end
end
