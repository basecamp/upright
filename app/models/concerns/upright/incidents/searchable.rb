module Upright::Incidents::Searchable
  extend ActiveSupport::Concern

  KINDS = { "incidents" => "Incidents", "maintenance" => "Maintenance" }

  included do
    scope :of_kind, ->(kind) {
      case kind
      when "incidents"   then reactive
      when "maintenance" then planned
      else all
      end
    }

    scope :affecting, ->(code) { code.present? ? for_service(code) : all }

    # Matches the title or any update's message.
    scope :mentioning, ->(query) {
      if query.present?
        pattern = "%#{sanitize_sql_like(query.squish)}%"
        updates = Upright::IncidentUpdate.where(Upright::IncidentUpdate.arel_table[:body].matches(pattern, "\\"))

        where(arel_table[:title].matches(pattern, "\\")).or(where(id: updates.select(:incident_id)))
      else
        all
      end
    }
  end
end
