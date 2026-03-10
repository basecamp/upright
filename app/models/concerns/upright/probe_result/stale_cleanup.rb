module Upright::ProbeResult::StaleCleanup
  extend ActiveSupport::Concern

  STALE_SUCCESS_THRESHOLD = 24.hours
  STALE_FAILURE_THRESHOLD = 30.days
  FAILURE_RETENTION_LIMIT = 1000

  class_methods do
    def cleanup_stale
      cleanup_stale_successes
      cleanup_stale_failures
    end

    def cleanup_stale_successes
      ok.where(created_at: ...STALE_SUCCESS_THRESHOLD.ago).in_batches.destroy_all
    end

    def cleanup_stale_failures
      cutoff = [
        STALE_FAILURE_THRESHOLD.ago,
        fail.order(created_at: :desc).offset(FAILURE_RETENTION_LIMIT).pick(:created_at)
      ].compact.max

      fail.where(created_at: ..cutoff).in_batches.destroy_all
    end
  end
end
