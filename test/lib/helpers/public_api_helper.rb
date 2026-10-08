module PublicApiHelper
  extend ActiveSupport::Concern

  included do
    setup do
      on_subdomain Upright.configuration.public_status_subdomain
      Upright.configuration.stubs(:public_status_json_enabled).returns(true)
      Upright::Service.any_instance.stubs(:live_status).returns(:operational)
      Upright::Service.any_instance.stubs(:current_outage_started_at).returns(nil)
      Upright::Incident.destroy_all
    end
  end

  private
    def json
      response.parsed_body
    end

    def declare_incident(title:, impact: "minor", service_codes: [ "example_app" ])
      Upright::Incident.create! title: title, impact: impact, starts_at: 1.hour.ago, service_codes: service_codes
    end

    def schedule_maintenance(starts_at:, ends_at:)
      Upright::Maintenance.create! title: "Planned failover", starts_at: starts_at, ends_at: ends_at, service_codes: [ "example_app" ]
    end
end
