require "test_helper"

class Upright::SiteTest < ActiveSupport::TestCase
  setup do
    @site = Upright::Site.new(
      code: "ams",
      city: "Amsterdam",
      country: "NL",
      geohash: "u173zq"
    )
  end

  test "host extracts hostname from url" do
    assert_equal "ams.upright.localhost", @site.host
  end

  test "default_timeout returns configuration value" do
    assert_equal Upright.configuration.default_timeout, @site.default_timeout
  end

  test "latitude decodes from geohash" do
    assert_in_delta 52.37, @site.latitude, 0.01
  end

  test "longitude decodes from geohash" do
    assert_in_delta 4.89, @site.longitude, 0.01
  end

  test "url builds subdomain url from code" do
    expected_port = ENV.fetch("PORT", 3000)
    assert_equal "http://ams.upright.localhost:#{expected_port}/", @site.url
  end

  test "to_leaflet returns map marker data" do
    expected_port = ENV.fetch("PORT", 3000)
    result = @site.to_leaflet

    assert_equal "ams.upright.localhost", result[:hostname]
    assert_equal "Amsterdam", result[:city]
    assert_in_delta 52.37, result[:lat], 0.01
    assert_in_delta 4.89, result[:lon], 0.01
    assert_equal "http://ams.upright.localhost:#{expected_port}/", result[:url]
  end
end
