class Upright::Service < FrozenRecord::Base
  def self.file_path
    Rails.root.join("config", "services.yml").to_s
  end

  def probe_rollups
    Upright::Rollups::ProbeRollup.where(probe_service: code)
  end

  def uptime_for(day)
    probe_rollups.where(period_start: day.beginning_of_day).minimum(:uptime_fraction)
  end

  def status_for(day)
    Upright::Rollups::ProbeRollup.status_for(uptime_for(day))
  end

  def daily_uptime(days: 90)
    probe_rollups
      .where(period_start: days.days.ago.beginning_of_day..)
      .group(:period_start)
      .minimum(:uptime_fraction)
  end
end
