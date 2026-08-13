require "test_helper"

class Upright::Traceroute::ResultTest < ActiveSupport::TestCase
  setup do
    @result = Upright::Traceroute::Result.new("example.com")
  end

  test "reached_destination? returns true when last hop responds" do
    stub_mtr_with_fixture(@result, "mtr_reached_destination")

    assert @result.reached_destination?
  end

  test "reached_destination? returns false when last hop is ???" do
    stub_mtr_with_fixture(@result, "mtr_unreachable_destination")

    assert_not @result.reached_destination?
  end

  test "reached_destination? returns false for empty hops" do
    stub_mtr_with_fixture(@result, "mtr_empty_hops")

    assert_not @result.reached_destination?
  end

  test "accepts hostnames and IP addresses" do
    [ "example.com", "sub-domain.example.com", "8.8.8.8", "2001:4860:4860::8888", "::1" ].each do |host|
      assert Upright::Traceroute::Result.new(host), "expected #{host.inspect} to be accepted"
    end
  end

  test "rejects hosts that could be treated as mtr flags or shell input" do
    [ "-c", "--raw", "-inet", "example.com --raw", "host;id", "$(id)", "", nil ].each do |host|
      assert_raises ArgumentError, "expected #{host.inspect} to be rejected" do
        Upright::Traceroute::Result.new(host)
      end
    end
  end
end
