require "test_helper"

class UprightTest < ActiveSupport::TestCase
  test "version number" do
    assert Upright::VERSION
  end

  test "primary_site finds the site declaring itself primary" do
    assert_equal :ams, Upright.primary_site.code
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
