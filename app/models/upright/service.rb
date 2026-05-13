class Upright::Service < FrozenRecord::Base
  def self.file_path
    Rails.root.join("config", "services.yml").to_s
  end

  def probes
    Upright::Probeable.probe_classes.flat_map do |klass|
      next [] unless klass.respond_to?(:all)
      klass.all.select { |probe| probe.probe_service.to_s == code.to_s }
    end
  end

  def probe_results
    Upright::ProbeResult.where(probe_service: code)
  end

  def latest_probe_rollups(days: 90)
    Upright::Rollups::ProbeRollup
      .where(probe_service: code)
      .where(period_start: days.days.ago.beginning_of_day..)
      .order(:period_start)
  end

  def latest_service_rollups(days: 90)
    Upright::Rollups::ServiceRollup
      .where(service_code: code)
      .where(period_start: days.days.ago.beginning_of_day..)
      .order(:period_start)
  end
end
