class Upright::Maintenance < Upright::Incident
  STATUSES          = %w[ scheduled in_progress completed ]
  TERMINAL_STATUSES = %w[ completed ]
  IMPACTS           = %w[ maintenance ]

  TEMPLATES = {
    scheduled: "We will be performing maintenance on %{services}.",
    in_progress: "Maintenance is underway.",
    completed: "Maintenance is complete."
  }

  STATUS_TEMPLATES = TEMPLATES.keys.index_by(&:to_s)

  SUPPRESSION_LEAD = 1.minute

  scope :suppressing, -> { unresolved.where(starts_at: ..SUPPRESSION_LEAD.from_now) }

  validates :ends_at, presence: true
  validate :ends_after_start

  before_validation :set_maintenance_impact

  def maintenance? = true

  # Codes of the services under maintenance now, looked up once per request or
  # job so pages that check every service run one query.
  def self.active_service_codes
    Upright::Current.maintenance_service_codes ||= active.joins(:affected_services).distinct.pluck(:service_code).to_set
  end

  def self.export_service_metrics
    Upright::Service.all.each do |service|
      Yabeda.upright_service_under_maintenance.set({ probe_service: service.code }, suppressing.for_service(service.code).exists? ? 1 : 0)
    end
  end

  def auto_advance_status(now: Time.current)
    record_update(status: "in_progress", body: "Maintenance is underway.") if scheduled? && now >= starts_at
    record_update(status: "completed",  body: "Maintenance is complete.")  if in_progress? && now >= ends_at
  end

  def update_body_for_status(status)
    update_body_for self.class::STATUS_TEMPLATES.fetch(status)
  end

  private
    def title_template
      "%{services} maintenance"
    end

    def set_maintenance_impact
      self.impact = "maintenance"
    end

    def ends_after_start
      errors.add(:ends_at, "must be after the start") if ends_at.present? && starts_at.present? && ends_at <= starts_at
    end
end
