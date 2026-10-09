class Upright::IncidentUpdate < Upright::PersistentRecord
  belongs_to :incident, class_name: "Upright::Incident", inverse_of: :updates

  validates :status, presence: true

  scope :written_by_people, -> { where.not(created_by: "System").or(where(created_by: nil)) }

  before_create { self.created_by ||= Upright::Current.user&.name || "System" }
end
