class Upright::Incident < Upright::PersistentRecord
  include Upright::Incidents::Lifecycle
  include Upright::Incidents::AutoReporting

  attr_accessor :body

  enum :status, %w[ investigating monitoring resolved
                    scheduled in_progress completed ].index_with(&:itself)
  enum :impact, %w[ minor major critical maintenance ].index_with(&:itself), prefix: true, default: "minor"

  STATUSES          = %w[ investigating monitoring resolved ]
  TERMINAL_STATUSES = %w[ resolved ]
  IMPACTS           = %w[ minor major critical ]

  IMPACT_STATUS = { "minor" => :degraded, "major" => :partial_outage, "critical" => :major_outage }

  TEMPLATES = {
    down: "%{services} %{is_or_are} down. We are investigating.",
    investigating: "We are investigating the cause and will post updates here.",
    back_up: "%{services} %{is_or_are} back up and operating normally."
  }

  def self.active_statuses
    reactive.active.map { |incident| IMPACT_STATUS.fetch(incident.impact) }
  end

  has_many :updates, -> { order(created_at: :desc) }, class_name: "Upright::IncidentUpdate", inverse_of: :incident, dependent: :destroy
  has_many :affected_services, class_name: "Upright::IncidentAffectedService", inverse_of: :incident, dependent: :destroy
  has_one :automatic_report, class_name: "Upright::Incident::AutomaticReport", inverse_of: :incident, dependent: :destroy

  # An incident is public-facing when it affects at least one public service.
  # Everything else — internal-only or untagged — stays off the public status
  # page entirely (fail closed).
  scope :public_facing, -> { for_service(Upright::Service.public_facing.map(&:code)).distinct }

  validates :title, :starts_at, presence: true
  validates :status, inclusion: { in: ->(incident) { incident.class::STATUSES } }
  validates :impact, inclusion: { in: ->(incident) { incident.class::IMPACTS } }

  before_validation :set_default_status, on: :create
  before_create { self.created_by ||= Upright::Current.user&.name }
  before_update { self.updated_by = Upright::Current.user.name if Upright::Current.user }
  after_create :record_initial_update

  def maintenance? = false

  def service_codes = affected_services.map(&:service_code)

  def service_codes=(codes)
    self.affected_services = Array(codes).reject(&:blank?).uniq.map do |code|
      affected_services.find { |s| s.service_code == code } ||
        affected_services.build(service_code: code)
    end
  end

  def services
    service_codes.filter_map { |code| Upright::Service.find_by(code: code) }
  end

  def public_services
    services.select { |service| service[:public] }
  end

  def update_body_for(key)
    subjects = services
    template = subjects.filter_map { |service| service.incident_update_template(key) }.uniq
    template = template.one? ? template.first : TEMPLATES.fetch(key)

    template % {
      services: subjects.any? ? subjects.map(&:name).to_sentence : "This service",
      is_or_are: subjects.many? ? "are" : "is"
    }
  end

  private
    def set_default_status
      self.status ||= self.class::STATUSES.first
    end

    def record_initial_update
      updates.create!(status: status, body: body.presence || default_initial_body)
    end

    def default_initial_body
      maintenance? ? "Maintenance scheduled." : "We are investigating."
    end
end
