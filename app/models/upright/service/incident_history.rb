class Upright::Service::IncidentHistory
  attr_reader :service, :page

  delegate :daily_status_history, :maintenance_active?, :name, to: :service

  def self.for(service, page: nil)
    new service, page: GearedPagination::Recordset.new(
      service.incidents.past.reorder(nil).preload(:updates), ordered_by: { starts_at: :desc }
    ).page(page)
  end

  def initialize(service, page:)
    @service = service
    @page = page
  end

  def active_incidents
    @active_incidents ||= service.incidents.reactive.active.preload(:updates)
  end

  def past_incidents
    page.records
  end
end
