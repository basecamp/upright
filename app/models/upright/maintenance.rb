class Upright::Maintenance < Upright::Incident
  STATUSES          = %w[ scheduled in_progress completed ]
  TERMINAL_STATUSES = %w[ completed ]
  IMPACTS           = %w[ maintenance ]

  SUPPRESSION_LEAD = 1.minute

  scope :suppressing, -> { unresolved.where(starts_at: ..SUPPRESSION_LEAD.from_now) }

  validates :ends_at, presence: true
  validate :ends_after_start

  before_validation :set_maintenance_impact

  def maintenance? = true

  def self.export_service_metrics
    Upright::Service.all.each do |service|
      Yabeda.upright_service_under_maintenance.set({ probe_service: service.code }, suppressing.for_service(service.code).exists? ? 1 : 0)
    end
  end

  def auto_advance_status(now: Time.current)
    record_update(status: "in_progress", body: "Maintenance is underway.") if scheduled? && now >= starts_at
    record_update(status: "completed",  body: "Maintenance is complete.")  if in_progress? && now >= ends_at
  end

  private
    def set_maintenance_impact
      self.impact = "maintenance"
    end

    def ends_after_start
      errors.add(:ends_at, "must be after the start") if ends_at.present? && starts_at.present? && ends_at <= starts_at
    end
end
