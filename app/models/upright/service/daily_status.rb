class Upright::Service::DailyStatus
  attr_reader :date, :status, :uptime_fraction

  def initialize(date:, status: nil, uptime_fraction: nil)
    @date            = date
    @status          = status
    @uptime_fraction = uptime_fraction
  end

  def operational?
    status == :operational
  end

  def tooltip
    "#{date_label}: #{body}"
  end

  private
    def date_label
      date == Date.current ? "Today" : date.to_fs(:month_day)
    end

    def body
      if uptime_fraction
        "%.2f%% uptime" % (uptime_fraction * 100)
      elsif status
        status.to_s.humanize.downcase
      else
        "no data"
      end
    end
end
