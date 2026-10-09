module Upright::IncidentsHelper
  # Wraps a text field or text area in a picker that offers past entries from
  # `url`. The named form fields are sent along so the server can rank for the
  # services and status being written about. With `autofill`, a change to those
  # fields replaces the text with the top suggestion unless someone has typed
  # their own.
  def suggestion_picker(url:, fields: [], autofill: false, &block)
    tag.div class: "picker", data: { controller: "suggestions", suggestions_url_value: url, suggestions_fields_value: fields, suggestions_autofill_value: autofill } do
      safe_join [
        capture(&block),
        tag.div(class: "picker__completion", aria: { hidden: true }, data: { suggestions_target: "completion" }),
        tag.ul(class: "picker__list", role: "listbox", hidden: true, data: { suggestions_target: "list" })
      ]
    end
  end

  def suggestion_input_data
    { suggestions_target: "input", action: "input->suggestions#input focus->suggestions#show blur->suggestions#hide keydown->suggestions#navigate scroll->suggestions#sync" }
  end

  def history_when_label(incident)
    if incident.maintenance?
      maintenance_window_description(incident)
    elsif incident.resolved_at
      "#{incident.starts_at.to_fs(:month_day_at_zone)}, resolved after #{distance_of_time_in_words(incident.starts_at, incident.resolved_at)}"
    else
      "Started #{incident.starts_at.to_fs(:month_day_at_zone)}"
    end
  end
end
