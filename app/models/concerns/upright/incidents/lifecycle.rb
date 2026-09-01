module Upright::Incidents::Lifecycle
  extend ActiveSupport::Concern

  included do
    scope :resolved,   -> { where.not(resolved_at: nil) }
    scope :unresolved, -> { where(resolved_at: nil) }

    scope :active,   -> { unresolved.where(starts_at: ..Time.current) }
    scope :upcoming, -> { unresolved.where(starts_at: Time.current..) }
    scope :past,     -> { resolved.order(starts_at: :desc) }

    scope :reactive, -> { where.not(type: "Upright::Maintenance").or(where(type: nil)) }
    scope :planned,  -> { where(type: "Upright::Maintenance") }

    scope :for_service, ->(code) {
      joins(:affected_services).where(upright_incident_affected_services: { service_code: code })
    }
  end

  def active?   = resolved_at.nil? && starts_at <= Time.current
  def upcoming? = resolved_at.nil? && starts_at > Time.current
  def past?     = resolved_at.present?

  def record_update(attributes = nil, recorded_at: Time.current, **update_attributes)
    attributes = attributes ? attributes.merge(update_attributes) : update_attributes

    updates.build(attributes.merge(created_at: recorded_at)).tap do |update|
      next unless update.valid?

      self.status = update.status
      if self.class::TERMINAL_STATUSES.include?(update.status)
        self.resolved_at ||= recorded_at
      end
      next unless valid?

      transaction do
        update.save
        save
        after_recording_terminal_status if self.class::TERMINAL_STATUSES.include?(update.status)
      end
    end
  end

  private
    def after_recording_terminal_status
    end
end
