class Upright::Public::StatusController < Upright::Public::BaseController
  DAYS = 90

  def show
    @services = Upright::Service.all
    @days = (DAYS - 1).downto(0).map { |n| n.days.ago.to_date }
    @today = Date.today
  end
end
