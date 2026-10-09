# Past titles and update messages to offer while writing an incident or a
# maintenance, ranked for the services it affects. A past entry about one
# service is offered with this incident's services in its place, so
# "Example App is down" is offered as "Other App is down".
class Upright::Incident::Suggestions
  LIMIT   = 50
  HISTORY = 500

  Suggestion = Data.define(:text, :uses)

  def initialize(incident)
    @incident = incident
  end

  def titles
    rank past_incidents.map { |incident| [ incident.title, incident ] }, fallback: @incident.default_title
  end

  # A new incident's first update draws only on the messages that opened past
  # incidents, so follow-ups such as "We are continuing to investigate" aren't
  # offered as an opening message.
  def messages(status:)
    updates = past_updates(status)
    updates = updates.group_by(&:incident_id).values.map { it.min_by(&:created_at) } if @incident.new_record?

    rank updates.map { |update| [ update.body, update.incident ] }, fallback: @incident.update_body_for_status(status)
  end

  private
    def past_incidents
      same_kind.where.not(id: @incident.id).preload(:affected_services).order(starts_at: :desc).limit(HISTORY)
    end

    def past_updates(status)
      Upright::IncidentUpdate.written_by_people
        .joins(:incident).merge(same_kind)
        .where(status: status).where.not(body: [ nil, "" ])
        .preload(incident: :affected_services)
        .order(created_at: :desc).limit(HISTORY)
    end

    def same_kind
      @incident.maintenance? ? Upright::Incident.planned : Upright::Incident.reactive
    end

    # Most related first, then most used, then most recent.
    def rank(entries, fallback:)
      suggestions = entries
        .group_by { |text, incident| adapt(text, from: incident) }
        .each_with_index
        .sort_by { |(_, rows), index| [ related?(rows) ? 0 : 1, -rows.size, index ] }
        .map { |(text, rows), _| Suggestion.new(text: text, uses: rows.size) }

      suggestions << Suggestion.new(text: fallback, uses: 0) unless suggestions.any? { it.text == fallback }
      suggestions.first(LIMIT)
    end

    def related?(rows)
      rows.any? { |_, incident| incident.service_codes.intersect?(@incident.service_codes) }
    end

    def adapt(text, from:)
      text = text.squish
      source_names = from.services.map(&:name)

      if source_names.one? && service_names.any? && source_names != service_names
        text.gsub(/\b#{Regexp.escape(source_names.first)}\b/, service_names.to_sentence)
      else
        text
      end
    end

    def service_names
      @service_names ||= @incident.services.map(&:name)
    end
end
