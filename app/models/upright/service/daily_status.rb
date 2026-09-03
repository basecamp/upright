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

  def date_label
    date == Date.current ? "Today" : date.to_fs(:month_day)
  end

  def detail
    if uptime_fraction
      [ "%.2f%% uptime" % (uptime_fraction * 100), downtime ].compact.join(" · ")
    elsif status
      status.to_s.humanize.downcase
    else
      "no data"
    end
  end

  def aria_label
    "#{date_label}: #{detail}"
  end

  private
    def downtime
      if uptime_fraction && uptime_fraction < 1
        minutes = ((1 - uptime_fraction) * 24 * 60).round
        minutes.zero? ? "<1 min down" : "#{minutes} #{'min'.pluralize(minutes)} down"
      end
    end
end
