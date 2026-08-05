class Upright::HealthMetricsJob < Upright::ApplicationJob
  queue_as :default

  def perform
    Yabeda.upright_primary_site.set({}, Upright.current_site&.primary? ? 1 : 0)

    if Upright::PersistentRecord.up?
      Yabeda.upright_persistent_db_up.set({}, 1)
      Upright::Rollups::ProbeRollup.export_metrics
    else
      Yabeda.upright_persistent_db_up.set({}, 0)
    end
  end
end
