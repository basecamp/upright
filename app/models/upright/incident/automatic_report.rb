class Upright::Incident::AutomaticReport < Upright::PersistentRecord
  belongs_to :incident, class_name: "Upright::Incident", inverse_of: :automatic_report, optional: true
end
