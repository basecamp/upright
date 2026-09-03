module Upright::ProbeResult::StaleCleanup
  extend ActiveSupport::Concern

  class_methods do
    def cleanup_stale
      cleanup_stale_successes
      cleanup_stale_failures
    end

    def cleanup_stale_successes
      ok.where(created_at: ...Upright.config.stale_success_threshold.ago).purge_in_batches
    end

    def cleanup_stale_failures
      cutoff = [
        Upright.config.stale_failure_threshold.ago,
        fail.order(created_at: :desc).offset(Upright.config.failure_retention_limit).pick(:created_at)
      ].compact.max

      fail.where(created_at: ..cutoff).purge_in_batches
    end

    # Delete records and their artifacts without going through destroy_all's
    # per-record callback cascade. has_many_attached's default dependent is
    # :purge_later, which enqueues one ActiveStorage::PurgeJob per attachment
    # — at ~13k attachments per hourly run on a busy site, that floods the
    # queue DB enough to contend with probe writes. Here we issue batched
    # DELETEs for the records and their attachment rows, then purge blobs
    # inline so no jobs are enqueued.
    def purge_in_batches
      in_batches do |batch|
        batch_ids = batch.pluck(:id)
        attachments = ActiveStorage::Attachment.where(record_type: name, record_id: batch_ids)
        blob_ids = attachments.distinct.pluck(:blob_id)

        attachments.delete_all
        batch.delete_all

        ActiveStorage::Blob.unattached.where(id: blob_ids).find_each do |blob|
          blob.purge
        rescue => e
          Rails.error.report(e)
        end
      end
    end
  end
end
