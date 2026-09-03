class Upright::IncidentAffectedService < Upright::PersistentRecord
  belongs_to :incident, class_name: "Upright::Incident", inverse_of: :affected_services

  validates :service_code, presence: true,
    uniqueness: { scope: :incident_id },
    inclusion: { in: ->(_) { Upright::Service.all.map(&:code) } }

  def service = Upright::Service.find_by(code: service_code)
end
