class Upright::IncidentUpdate < Upright::PersistentRecord
  belongs_to :incident, class_name: "Upright::Incident", inverse_of: :updates

  validates :status, presence: true

  before_create { self.created_by ||= Upright::Current.user&.name || "System" }
end
