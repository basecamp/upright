class Upright::IncidentReporterJob < Upright::ApplicationJob
  queue_as :default

  def perform
    Upright::Incident.report_downtime
  end
end
