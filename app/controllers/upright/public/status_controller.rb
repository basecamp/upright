class Upright::Public::StatusController < Upright::Public::BaseController
  DAYS = 90
  STATUS_PRIORITY = %i[ major_outage partial_outage degraded_performance operational ].freeze

  def show
    @services = Upright::Service.all
    @days = (DAYS - 1).downto(0).map { |n| n.days.ago.to_date }
    @today = Date.today
    @overall_status = compute_overall_status(@services, @today)
  end

  private
    def compute_overall_status(services, day)
      STATUS_PRIORITY.find { |status| services.any? { |service| service.status_for(day) == status } } || :operational
    end
end
