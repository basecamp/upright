require "test_helper"

class Upright::ApplicationControllerTest < ActiveSupport::TestCase
  test "URLs built during a site request use the site's host" do
    assert_equal "ams.upright.localhost", URI(controller_on("ams.upright.localhost").upright.site_root_url).host
  end

  test "URLs can still target another subdomain" do
    assert_equal "app.upright.localhost", URI(controller_on("ams.upright.localhost").upright.root_url(subdomain: "app")).host
  end

  private
    def controller_on(host)
      Upright::ApplicationController.new.tap do |controller|
        controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => host)
      end
    end
end
