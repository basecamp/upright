class Upright::HealthMetricsJob < Upright::ApplicationJob
  queue_as :default

  def perform
    Yabeda.upright_primary_site.set({}, primary? ? 1 : 0)

    # Probe-only sites are firewalled off the persistent database, where a
    # connection attempt hangs rather than being refused and ties up this worker.
    if stores_metrics?
      if Upright::PersistentRecord.up?
        Yabeda.upright_persistent_db_up.set({}, 1)
        Upright::Rollups::ProbeRollup.export_metrics
      else
        Yabeda.upright_persistent_db_up.set({}, 0)
      end
    end
  end

  private
    def primary?
      Upright.current_site&.primary?
    end

    def stores_metrics?
      Upright.current_site&.stores_metrics?
    end
end
