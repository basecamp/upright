class Upright::ProbeResult < Upright::ApplicationRecord
  include Upright::ExceptionRecording

  attr_accessor :probe_alert_severity

  has_many_attached :artifacts

  scope :by_type,   ->(type) { where(probe_type: type) if type.present? }
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :by_name,   ->(name) { where(probe_name: name) if name.present? }
  scope :stale,     -> { where(created_at: ...24.hours.ago) }

  enum :status, [ :ok, :fail ]

  after_create :increment_metrics

  def to_chart
    {
      probe_name:  probe_name,
      status:     status,
      created_at: created_at.iso8601,
      duration:   duration.to_f
    }
  end

  private
    def increment_metrics
      labels = { type: probe_type, name: probe_name, probe_target: probe_target, probe_service: probe_service, alert_severity: probe_alert_severity || :high }

      Yabeda.upright_probe_duration_seconds.set(labels.merge(status: status), duration.to_f)
      Yabeda.upright_probe_up.set(labels, ok? ? 1 : 0)
    end
end
