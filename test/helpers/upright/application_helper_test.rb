require "test_helper"

class Upright::ApplicationHelperTest < ActionView::TestCase
  test "public_stylesheets default to an empty array" do
    assert_equal [], Upright::Configuration.new.public_stylesheets
  end

  test "public_stylesheets wraps a lone value in an array" do
    config = Upright::Configuration.new
    config.public_stylesheets = "upright/theme"
    assert_equal [ "upright/theme" ], config.public_stylesheets
  end

  test "upright_stylesheet_link_tag renders only the engine's stylesheets by default" do
    hrefs = upright_stylesheet_link_tag.scan(/href="([^"]+)"/).flatten

    assert hrefs.any? { |h| h.include?("/upright/base") }
    assert_equal 1, hrefs.count { |h| h.include?("/upright/reset") }
  end

  test "upright_stylesheet_link_tag appends configured public stylesheets after the engine's" do
    # upright/theme is a dummy-app fixture (test/dummy/app/assets/stylesheets),
    # standing in for a host app's theme override.
    Upright.configuration.stubs(:public_stylesheets).returns([ "upright/theme" ])

    hrefs = upright_stylesheet_link_tag.scan(/href="([^"]+)"/).flatten

    assert hrefs.any? { |h| h.include?("/upright/base") }, "engine stylesheets still present"
    assert_match %r{/upright/theme}, hrefs.last, "host override loads last"
  end
end
