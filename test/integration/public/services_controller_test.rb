require "test_helper"

class Upright::Public::ServicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    on_subdomain Upright.configuration.public_status_subdomain
    Upright::Service.any_instance.stubs(:live_status).returns(:operational)
    Upright::Service.any_instance.stubs(:current_outage_started_at).returns(nil)
  end

  test "index renders HTML with a short public cache" do
    get upright.public_services_root_path

    assert_response :success
    assert_match %r{text/html}, response.content_type
    assert_equal "max-age=15, public", response.headers["Cache-Control"]
  end

  test "index serves the HTML page to clients that ask for another format" do
    get upright.public_services_root_path, headers: { "Accept" => "application/json" }

    assert_response :success
    assert_match %r{text/html}, response.content_type
    assert_equal "max-age=15, public", response.headers["Cache-Control"]
  end

  test "feed still serves RSS" do
    get upright.public_services_feed_path, headers: { "Accept" => "application/json" }

    assert_response :success
    assert_match %r{application/rss\+xml}, response.content_type
  end

  test "index uses the configured title for the page and the feed" do
    Upright.configuration.stubs(:public_status_title).returns("Example Status")

    get upright.public_services_root_path
    assert_match "<title>Example Status</title>", response.body

    get upright.public_services_feed_path
    assert_match "<title>Example Status</title>", response.body
  end

  test "index loads only the public JavaScript entry point" do
    get upright.public_services_root_path

    assert_response :success
    assert_match %(import "upright/public"), response.body
    assert_match %r{<link rel="modulepreload" href="[^"]*local-time}, response.body
    assert_no_match(/import "application"/, response.body)
    assert_no_match(%r{<link rel="modulepreload" href="[^"]*(turbo|stimulus|leaflet|frappe)}, response.body)
  end

  test "index loads only the public stylesheets" do
    get upright.public_services_root_path

    assert_response :success
    tags = response.body.scan(/<link[^>]*rel="stylesheet"[^>]*>/)
    names = tags.map { |tag| File.basename(tag[/href="([^"]+)"/, 1]).sub(/(-[0-9a-f]+)?\.css\z/, "") }
    assert_equal %w[ _global base layout pagination public_status reset typography ], names
  end

  test "feed renders an RSS document" do
    get upright.public_services_feed_path

    assert_response :success
    assert_match %r{application/rss\+xml}, response.content_type
    assert_match %r{<rss version="2\.0">}, response.body
    assert_match "<title>Status</title>", response.body
    assert_match "<channel>", response.body
  end

  test "feed links use the request's host by default" do
    incident = raise_public_incident

    get upright.public_services_feed_path

    assert_select "channel > link", text: "http://status.upright.localhost"
    assert_select "item > link", text: "http://status.upright.localhost#{upright.public_incident_path(incident)}"
  end

  test "feed links use the configured public status URL" do
    Upright.configuration.stubs(:public_status_url).returns("https://status.example.com/")
    incident = raise_public_incident

    get upright.public_services_feed_path

    assert_select "channel > link", text: "https://status.example.com"
    assert_select "item > link", text: "https://status.example.com#{upright.public_incident_path(incident)}"
  end

  test "index shows incidents affecting public services and hides internal-only or untagged ones" do
    raise_public_incident
    raise_internal_incident

    get upright.public_services_root_path

    assert_response :success
    assert_match "Example App is on fire", response.body
    assert_no_match(/Internal tools are down/, response.body)
    assert_no_match(/Rolling restart/, response.body) # active maintenance not tagged to a public service
  end

  test "an internal-only incident does not change the overall status banner" do
    raise_internal_incident impact: "critical"

    get upright.public_services_root_path

    assert_response :success
    assert_match "All Systems Operational", response.body
  end

  test "a public-facing incident raises the overall status banner" do
    raise_public_incident impact: "critical"

    get upright.public_services_root_path

    assert_response :success
    assert_match "Major Outage", response.body
  end

  test "feed only carries incidents affecting public services" do
    raise_public_incident
    raise_internal_incident

    get upright.public_services_feed_path

    assert_response :success
    assert_match "Example App is on fire", response.body
    assert_no_match(/Internal tools are down/, response.body)
  end

  test "upcoming maintenance affecting a mix of services names only the public ones" do
    Upright::Maintenance.create! title: "Planned failover", impact: "maintenance",
      starts_at: 1.hour.from_now, ends_at: 2.hours.from_now,
      service_codes: [ "example_app", "internal_tools" ]

    get upright.public_services_root_path

    assert_response :success
    assert_match "Planned failover", response.body
    assert_match "Example App", response.body
    assert_no_match(/Internal Tools/, response.body)
  end

  private
    def raise_public_incident(impact: "major")
      Upright::Incident.create! title: "Example App is on fire", impact: impact,
        starts_at: 1.hour.ago, service_codes: [ "example_app" ]
    end

    def raise_internal_incident(impact: "critical")
      Upright::Incident.create! title: "Internal tools are down", impact: impact,
        starts_at: 1.hour.ago, service_codes: [ "internal_tools" ]
    end
end
