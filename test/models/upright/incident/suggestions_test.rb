require "test_helper"

class Upright::Incident::SuggestionsTest < ActiveSupport::TestCase
  setup { travel_to Time.utc(2026, 6, 15, 12) }

  test "messages from incidents on the same services come before more-used messages from other services" do
    2.times { post_message "We are continuing to investigate this issue.", services: [ "internal_tools" ] }
    post_message "Example App is still slow. We are investigating.", services: [ "example_app" ]

    texts = suggested_messages(services: [ "example_app" ])

    assert_operator texts.index("Example App is still slow. We are investigating."), :<, texts.index("We are continuing to investigate this issue.")
  end

  test "among equally related messages, the most used comes first" do
    post_message "Rarely used.", services: [ "internal_tools" ]
    2.times { post_message "Often used.", services: [ "internal_tools" ] }

    texts = suggested_messages(services: [ "example_app" ])

    assert_operator texts.index("Often used."), :<, texts.index("Rarely used.")
  end

  test "a message about another service is offered with this incident's service" do
    post_message "Internal Tools is down. We are investigating.", services: [ "internal_tools" ]

    texts = suggested_messages(services: [ "example_app" ])

    assert_includes texts, "Example App is down. We are investigating."
    assert_not_includes texts, "Internal Tools is down. We are investigating."
  end

  test "messages Upright posts itself are not suggested" do
    post_message "Posted automatically.", services: [ "example_app" ], created_by: "System"

    assert_not_includes suggested_messages(services: [ "example_app" ]), "Posted automatically."
  end

  test "only messages with the requested status are suggested" do
    post_message "All clear.", services: [ "example_app" ], status: "resolved"

    assert_not_includes suggested_messages(services: [ "example_app" ]), "All clear."
    assert_includes suggested_messages(services: [ "example_app" ], status: "resolved"), "All clear."
  end

  test "maintenance and incident messages are kept apart" do
    maintenance = upright_incidents(:upcoming)
    maintenance.updates.create!(status: "scheduled", body: "Upgrading the database.", created_by: "Person")
    post_message "Incident message.", services: [ "example_app" ]

    texts = Upright::Maintenance.new(service_codes: [ "example_app" ]).suggestions.messages(status: "scheduled").map(&:text)

    assert_includes texts, "Upgrading the database."
    assert_not_includes texts, "Incident message."
  end

  test "a new incident's first update is offered only messages that opened past incidents" do
    incident = post_message "Example App is down.", services: [ "example_app" ]
    incident.incident.updates.create!(status: "investigating", body: "Still looking.", created_by: "Person", created_at: 1.minute.from_now)

    assert_includes suggested_messages(services: [ "example_app" ]), "Example App is down."
    assert_not_includes suggested_messages(services: [ "example_app" ]), "Still looking."
    assert_includes upright_incidents(:reactive_resolved).suggestions.messages(status: "investigating").map(&:text), "Still looking."
  end

  test "the status template is offered last" do
    post_message "We are looking into it.", services: [ "example_app" ]

    suggestions = Upright::Incident.new(service_codes: [ "example_app" ]).suggestions.messages(status: "investigating")

    assert_equal "We are checking Example App.", suggestions.last.text
    assert_equal 0, suggestions.last.uses
  end

  test "the first update of a new critical incident falls back to saying the services are down" do
    incident = Upright::Incident.new(service_codes: [ "example_app", "internal_tools" ], impact: "critical")

    assert_equal "Example App and Internal Tools are down. We are investigating.", incident.update_body_for_status("investigating")
  end

  test "titles from incidents on the same services come first, then the default title" do
    Upright::Incident.create!(title: "Internal Tools trouble", starts_at: Time.current, service_codes: [ "internal_tools" ])
    Upright::Incident.create!(title: "Example App outage", starts_at: Time.current, service_codes: [ "example_app" ])

    texts = Upright::Incident.new(service_codes: [ "example_app" ], impact: "critical").suggestions.titles.map(&:text)

    assert_equal "Example App outage", texts.first
    assert_equal "Example App is down", texts.last
  end

  test "a maintenance title defaults to naming the services" do
    assert_equal "Example App maintenance", Upright::Maintenance.new(service_codes: [ "example_app" ]).default_title
  end

  private
    def post_message(body, services:, status: "investigating", created_by: "Person")
      incident = Upright::Incident.create!(title: "Past incident", starts_at: 1.day.ago, service_codes: services)
      incident.updates.create!(status: status, body: body, created_by: created_by)
    end

    def suggested_messages(services:, status: "investigating")
      Upright::Incident.new(service_codes: services).suggestions.messages(status: status).map(&:text)
    end
end
