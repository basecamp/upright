class Upright::Public::StatusJsonController < Upright::Public::BaseController
  skip_before_action :serve_html_for_unsupported_formats
  before_action :require_public_status_json_enabled
  before_action { expires_in CACHE_TTL, public: true }

  def summary                = render(json: status_json.summary)
  def overall_status         = render(json: status_json.overall_status)
  def components             = render(json: status_json.components)
  def incidents              = render(json: status_json.incidents)
  def unresolved_incidents   = render(json: status_json.unresolved_incidents)
  def scheduled_maintenances = render(json: status_json.scheduled_maintenances)
  def upcoming_maintenances  = render(json: status_json.upcoming_maintenances)
  def active_maintenances    = render(json: status_json.active_maintenances)

  private
    def require_public_status_json_enabled
      render_not_found unless Upright.configuration.public_status_json_enabled
    end

    def status_json
      Upright::Service::StatusPage::JsonFormat.new(Upright::Service::StatusPage.current, url: helpers.public_status_base_url)
    end
end
