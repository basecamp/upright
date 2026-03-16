module Upright::ProbeResult::StaleCleanup
  extend ActiveSupport::Concern

  class_methods do
    def cleanup_stale
      cleanup_stale_successes
      cleanup_stale_failures
    end

    def cleanup_stale_successes
      ok.where(created_at: ...Upright.config.stale_success_threshold.ago).in_batches.destroy_all
    end

    def cleanup_stale_failures
      cutoff = [
        Upright.config.stale_failure_threshold.ago,
        fail.order(created_at: :desc).offset(Upright.config.failure_retention_limit).pick(:created_at)
      ].compact.max

      fail.where(created_at: ..cutoff).in_batches.destroy_all
    end
  end
end
