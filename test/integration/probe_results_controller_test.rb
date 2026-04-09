require "test_helper"

class ProbeResultsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in
    on_subdomain "ams"
  end

  test "gets index when signed in" do
    get upright.site_root_path
    assert_response :success
  end

  test "renders filter links for all registered probe types" do
    get upright.site_root_path
    assert_response :success

    Upright.probe_types.each do |probe_type|
      assert_select "aside a[href*='probe_type=#{probe_type.type}']", text: /#{probe_type.name}/
    end
  end

  test "filters by probe type when signed in" do
    get upright.site_root_path(probe_type: "playwright")
    assert_response :success
    assert_select "p", text: /for Playwright probes/
    assert_select "td", text: /#{upright_probe_results(:playwright_probe_result).probe_name}/
    assert_select "td", text: /#{upright_probe_results(:http_probe_result).probe_name}/, count: 0
  end

  test "filters by probe name when signed in" do
    get upright.site_root_path(probe_name: "HTTP Probe")
    assert_response :success
    assert_select "p", text: /named HTTP Probe/
    assert_select "td", text: /#{upright_probe_results(:http_probe_result).probe_name}/
    assert_select "td", text: /#{upright_probe_results(:playwright_probe_result).probe_name}/, count: 0
  end

  test "redirects to authentication when not signed in" do
    sign_out
    get upright.site_root_path
    assert_redirected_to upright.new_admin_session_url(subdomain: "app")
  end

  test "renders chart container with data" do
    get upright.site_root_path
    assert_response :success
    assert_select "[data-controller='probe-results-chart']"
    assert_select "[data-probe-results-chart-results-value]"
  end

  test "chart data includes all results when unfiltered" do
    get upright.site_root_path
    chart_data = JSON.parse(css_select("[data-probe-results-chart-results-value]").first["data-probe-results-chart-results-value"])

    assert_equal Upright::ProbeResult.count, chart_data.length
    assert chart_data.all? { |r| r.key?("created_at") && r.key?("duration") && r.key?("status") && r.key?("probe_name") }
  end

  test "chart data respects probe type filter" do
    get upright.site_root_path(probe_type: "http")
    chart_data = JSON.parse(css_select("[data-probe-results-chart-results-value]").first["data-probe-results-chart-results-value"])

    assert chart_data.all? { |r| r["probe_name"] == "HTTP Probe" }
  end

  test "chart data respects status filter" do
    get upright.site_root_path(status: "fail")
    chart_data = JSON.parse(css_select("[data-probe-results-chart-results-value]").first["data-probe-results-chart-results-value"])

    assert chart_data.all? { |r| r["status"] == "fail" }
    assert_equal 4, chart_data.length
  end

  test "paginates results when there are many" do
    16.times { |i| Upright::ProbeResult.create!(probe_type: "http", probe_name: "Paginated", status: :ok, duration: i) }

    get upright.site_root_path

    assert_response :success
    assert_select "nav.pagination"
    assert_select ".pagination__info", text: /Page 1 of/
    assert_select ".pagination__prev--disabled"
    assert_select "a.pagination__next"
  end

  test "pagination preserves filters" do
    16.times { |i| Upright::ProbeResult.create!(probe_type: "http", probe_name: "Paginated", status: :ok, duration: i) }

    get upright.site_root_path(probe_type: "http")

    assert_response :success
    assert_select "a.pagination__next[href*='probe_type=http']"
  end

  test "filters by date" do
    get upright.site_root_path(date: Date.current.iso8601)
    assert_response :success
    assert_select "p", text: /on #{Date.current.to_fs(:long)}/
    assert_select "a.filter-clear", text: /Clear date filter/
  end

  test "renders artifacts for probe results with attachments" do
    result = upright_probe_results(:http_probe_result)
    assert result.artifacts.attached?, "Test fixture should have attached artifact"

    get upright.site_root_path

    assert_response :success
    assert_select "details.artifact"
  end
end
