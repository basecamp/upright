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

  test "feed renders an RSS document" do
    get upright.public_services_feed_path

    assert_response :success
    assert_match %r{application/rss\+xml}, response.content_type
    assert_match %r{<rss version="2\.0">}, response.body
    assert_match "<title>Upright Status</title>", response.body
    assert_match "<channel>", response.body
  end
end
