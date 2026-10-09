module Upright::IncidentsHelper
  # Wraps a text field or text area in a picker that offers past entries from
  # `url`. The named form fields are sent along so the server can rank for the
  # services and status being written about. With `autofill`, a change to those
  # fields replaces the text with the top suggestion until someone types.
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
end
