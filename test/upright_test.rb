require "test_helper"

class UprightTest < ActiveSupport::TestCase
  test "version number" do
    assert Upright::VERSION
  end

  test "primary_site finds the site declaring itself primary" do
    assert_equal :ams, Upright.primary_site.code
  end

  test "current_site refuses to guess when SITE_SUBDOMAIN names no known site" do
    error = assert_raises Upright::ConfigurationError do
      with_env("SITE_SUBDOMAIN" => "ahs") { Upright.current_site }
    end

    assert_match "SITE_SUBDOMAIN=ahs is not a site", error.message
  end

  test "current_site falls back to the first site only when SITE_SUBDOMAIN is unset" do
    with_env("SITE_SUBDOMAIN" => nil) do
      assert_equal Upright.sites.first.code, Upright.current_site.code
    end
  end

  test "loading rejects more than one primary site" do
    error = assert_raises Upright::ConfigurationError do
      load_sites_from [ { code: "ams", primary: true }, { code: "nyc", primary: true } ]
    end

    assert_match "declares 2 primary sites (ams, nyc)", error.message
  end

  test "loading allows no primary site, which is how a host looks before adopting the flag" do
    assert_nothing_raised do
      assert_nil load_sites_from([ { code: "ams" }, { code: "nyc" } ]).find(&:primary?)
    end
  end

  private
    def load_sites_from(sites)
      Rails.application.stubs(:config_for).with(:sites).returns({ sites: sites })
      Upright.send(:load_sites)
    end
end
