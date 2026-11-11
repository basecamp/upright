require "test_helper"

class Upright::IncidentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in
    on_subdomain :app
  end

  test "lists incidents and maintenances by month, newest first" do
    get upright.incidents_path

    assert_response :success
    assert_select ".incident-row", count: Upright::Incident.count
    assert_select ".incident-section__title", text: "June 2026"
  end

  test "lists active and upcoming events above the history" do
    travel_to Time.utc(2026, 6, 15, 12) do
      get upright.incidents_path
    end

    assert_select ".incident-section:nth-of-type(1) .incident-section__title", text: "Active"
    assert_select ".incident-section:nth-of-type(1) .incident-row__title", text: "Rolling restart"
    assert_select ".incident-section:nth-of-type(2) .incident-section__title", text: "Upcoming"
    assert_select ".incident-section:nth-of-type(2) .incident-row__title", text: "Scheduled upgrade"
    assert_select ".incident-section:nth-of-type(3) .incident-section__title", text: "June 2026"
    assert_select ".incident-section:nth-of-type(3) .incident-row__title", text: "Resolved outage"
  end

  test "offers new incidents and maintenances" do
    get upright.incidents_path

    assert_select ".incidents-actions a[href='#{upright.new_incident_path}']", text: "New incident"
    assert_select ".incidents-actions a[href='#{upright.new_incident_path(maintenance: true)}']", text: "New maintenance"
  end

  test "filters by type" do
    get upright.incidents_path(kind: "maintenance")

    assert_select ".incident-row", count: Upright::Maintenance.count
    assert_select ".incident-row--maintenance", count: Upright::Maintenance.count
  end

  test "filters by service" do
    get upright.incidents_path(service: "example_app")

    assert_select ".incident-row", count: Upright::Incident.for_service("example_app").count
  end

  test "searches titles and update messages" do
    get upright.incidents_path(q: "investigating")

    assert_select ".incident-row__title", text: "Resolved outage"
    assert_select ".incident-row", count: 1
  end

  test "says when nothing matches" do
    get upright.incidents_path(q: "no such incident")

    assert_select ".incidents-empty__headline", text: "Nothing found"
  end

  test "says all clear when there's nothing at all" do
    Upright::Incident.destroy_all

    get upright.incidents_path

    assert_select ".incidents-empty__headline", text: "All clear"
  end

  test "the header links to the incidents page as Events" do
    get upright.incidents_path

    assert_select ".header__link[href$='#{upright.incidents_path}']", text: "Events"
  end

  test "creating an incident opens it" do
    post upright.incidents_path, params: { incident: incident_params }

    assert_redirected_to upright.edit_incident_path(Upright::Incident.last)
  end

  test "an incident left to start now starts when it's created, not when the form was opened" do
    travel_to Time.zone.parse("2026-10-09 15:00:00") do
      post upright.incidents_path, params: { incident: incident_params(starts_at: "2026-10-09T14:00") }
    end

    assert_equal Time.zone.parse("2026-10-09 15:00:00"), Upright::Incident.last.starts_at
  end

  test "an incident whose start was changed keeps the chosen time" do
    travel_to Time.zone.parse("2026-10-09 15:00:00") do
      post upright.incidents_path, params: { change_starts_at: "1", incident: incident_params(starts_at: "2026-10-09T14:00") }
    end

    assert_equal Time.zone.parse("2026-10-09 14:00:00"), Upright::Incident.last.starts_at
  end

  test "creating an incident without an affected service shows an error" do
    assert_no_difference -> { Upright::Incident.count } do
      post upright.incidents_path, params: { incident: incident_params(service_codes: [ "" ]) }
    end

    assert_response :unprocessable_entity
    assert_select ".incident-errors li", text: "Affected services must include at least one service"
  end

  test "the start time is prefilled to the minute so whole-minute times are valid" do
    travel_to Time.zone.parse("2026-10-09 14:29:17") do
      get upright.new_incident_path
    end

    assert_select "input[name='incident[starts_at]'][value='2026-10-09T14:29']"
  end

  test "the header of an active incident shows its status" do
    incident = Upright::Incident.create!(incident_params)

    get upright.edit_incident_path(incident)

    assert_select ".incident-form__eyebrow", text: "Incident · Investigating"
    assert_select ".incident-form--resolved", count: 0
  end

  test "the header of a resolved incident shows it is resolved" do
    get upright.edit_incident_path(upright_incidents(:reactive_resolved))

    assert_select ".incident-editor--resolved .incident-form--resolved .incident-form__eyebrow", text: "Incident · Resolved"
  end

  test "the new form lists services before the title and offers past titles" do
    get upright.new_incident_path

    assert_select ".field:has(.chips) ~ .field [data-controller=suggestions] input[name='incident[title]']"
    assert_select "[data-controller=suggestions] textarea[name='incident[body]']"
  end

  test "the new form labels its times with the zone they're entered in" do
    travel_to Time.utc(2026, 10, 9, 14, 29) do
      get upright.new_incident_path(maintenance: true)
    end

    assert_select "label[for=incident_starts_at]", text: "Starts (UTC)"
    assert_select "label[for=incident_ends_at]", text: "Ends (UTC)"
    assert_select ".field--starts-at .field__hint", text: "It’s 14:29 UTC now."
  end

  test "the new form pauses autofill while maintenance is chosen" do
    get upright.new_incident_path(maintenance: true)

    assert_select "[data-suggestions-autofill-unless-value='#kind_maintenance:checked'] input[name='incident[title]']"
    assert_select "[data-suggestions-autofill-unless-value='#kind_maintenance:checked'] textarea[name='incident[body]']"
    assert_select "input#kind_maintenance[checked]"
  end

  test "the update composer has a button for each status, with the current one chosen and its most used message filled in" do
    incident = Upright::Incident.create!(incident_params)

    get upright.edit_incident_path(incident)

    assert_select ".composer input[type=radio][name='incident_update[status]']", count: 3
    assert_select ".composer input#update_status_investigating[checked]"
    assert_select ".composer textarea[name='incident_update[body]']", text: "We are investigating."
  end

  private
    def incident_params(**overrides)
      { title: "Example App is down", impact: "critical", starts_at: Time.current, service_codes: [ "example_app" ] }.merge(overrides)
    end
end
