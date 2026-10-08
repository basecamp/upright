# Renders the public status page as the v2 status JSON that status widgets,
# aggregators and chat integrations commonly read: page, status, components,
# incidents and scheduled maintenances.
class Upright::Service::StatusPage::JsonFormat
  INDICATORS = { operational: "none", degraded: "minor", partial_outage: "major", major_outage: "critical", maintenance: "maintenance" }
  COMPONENT_STATUSES = { operational: "operational", degraded: "degraded_performance", partial_outage: "partial_outage", major_outage: "major_outage" }
  INCIDENT_LIMIT = 50

  def initialize(status_page, url:)
    @status_page = status_page
    @url = url
  end

  def summary
    with_page \
      components: components_json,
      incidents: incidents_json(reactive_incidents.unresolved),
      scheduled_maintenances: incidents_json(maintenances.unresolved),
      status: status_json
  end

  def overall_status
    with_page status: status_json
  end

  def components
    with_page components: components_json
  end

  def incidents
    with_page incidents: incidents_json(reactive_incidents.limit(INCIDENT_LIMIT))
  end

  def unresolved_incidents
    with_page incidents: incidents_json(reactive_incidents.unresolved)
  end

  def scheduled_maintenances
    with_page scheduled_maintenances: incidents_json(maintenances.limit(INCIDENT_LIMIT))
  end

  def upcoming_maintenances
    with_page scheduled_maintenances: incidents_json(maintenances.upcoming)
  end

  def active_maintenances
    with_page scheduled_maintenances: incidents_json(maintenances.active)
  end

  private
    attr_reader :status_page, :url

    def with_page(**data)
      { page: page_json, **data }
    end

    def page_json
      { id: page_id, name: Upright.configuration.public_status_title, url: url, time_zone: "Etc/UTC", updated_at: timestamp(Time.current) }
    end

    def page_id
      Upright.configuration.service_name
    end

    def status_json
      overall = status_page.overall_status
      { indicator: INDICATORS.fetch(overall), description: Upright::Public::ServicesHelper::OVERALL_STATUS_LABELS.fetch(overall) }
    end

    def components_json
      status_page.services.each_with_index.map { |service, index| component_json(service, position: index + 1) }
    end

    def component_json(service, position: nil)
      {
        id: service.code,
        name: service.name,
        status: component_status(service),
        description: service.try(:description).presence,
        position: position,
        showcase: true,
        only_show_if_degraded: false,
        group: false,
        group_id: nil,
        page_id: page_id,
        start_date: nil,
        created_at: nil,
        updated_at: timestamp(Time.current)
      }
    end

    def component_status(service)
      service.maintenance_active? ? "under_maintenance" : COMPONENT_STATUSES.fetch(service.live_status)
    end

    def reactive_incidents
      Upright::Incident.public_facing.reactive.order(starts_at: :desc).includes(:updates, :affected_services)
    end

    def maintenances
      Upright::Maintenance.public_facing.order(starts_at: :desc).includes(:updates, :affected_services)
    end

    def incidents_json(incidents)
      incidents.map { |incident| incident_json(incident) }
    end

    def incident_json(incident)
      {
        id: incident.id.to_s,
        name: incident.title,
        status: incident.status,
        impact: incident.impact,
        created_at: timestamp(incident.created_at),
        updated_at: timestamp(incident.updated_at),
        started_at: timestamp(incident.starts_at),
        monitoring_at: timestamp(incident.updates.select { |update| update.status == "monitoring" }.min_by(&:created_at)&.created_at),
        resolved_at: timestamp(incident.resolved_at),
        shortlink: "#{url}/incidents/#{incident.id}",
        page_id: page_id,
        incident_updates: incident.updates.map { |update| incident_update_json(incident, update) },
        components: incident.public_services.map { |service| component_json(service) }
      }.merge(maintenance_window_json(incident))
    end

    def maintenance_window_json(incident)
      if incident.maintenance?
        { scheduled_for: timestamp(incident.starts_at), scheduled_until: timestamp(incident.ends_at) }
      else
        {}
      end
    end

    def incident_update_json(incident, update)
      {
        id: update.id.to_s,
        status: update.status,
        body: update.body,
        incident_id: incident.id.to_s,
        created_at: timestamp(update.created_at),
        updated_at: timestamp(update.created_at),
        display_at: timestamp(update.created_at),
        affected_components: nil
      }
    end

    def timestamp(time)
      time&.utc&.iso8601(3)
    end
end
