require "test_helper"

class ArtifactsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in
    on_subdomain "ams"
  end

  test "shows text artifact content" do
    attachment = active_storage_attachments(:http_artifact)
    ActiveStorage::Attachment.any_instance.stubs(:download).returns("Sample log content")

    get upright.site_artifact_path(attachment)

    assert_response :success
    assert_select "pre", text: "Sample log content"
  end

  test "shows video artifact with video player" do
    attachment = active_storage_attachments(:playwright_video_artifact)

    get upright.site_artifact_path(attachment)

    assert_response :success
    assert_select "video[controls]"
    assert_select "source[type='video/webm']"
    assert_select "source[src*='rails/active_storage/blobs']"
  end

  test "falls back to the local command when no viewer is configured" do
    Upright.configuration.stubs(:trace_viewer_url).returns(nil)
    attachment = active_storage_attachments(:playwright_trace_artifact)

    get upright.site_artifact_path(attachment)

    assert_response :success
    assert_select "iframe", false
    assert_select "a[target='_blank']", false
    assert_select "code", text: "npx playwright show-trace trace.zip"
  end

  test "shows only the viewer link when a viewer is configured" do
    attachment = active_storage_attachments(:playwright_trace_artifact)

    get upright.site_artifact_path(attachment)

    assert_response :success
    assert_select "iframe", false
    assert_select "a[target='_blank']"
    assert_select "code", false
  end

  test "links a trace to a configured viewer origin" do
    Upright.configuration.stubs(:trace_viewer_url).returns("https://traces.example.net/index.html")
    attachment = active_storage_attachments(:playwright_trace_artifact)

    get upright.site_artifact_path(attachment)

    assert_response :success
    assert_select "a[rel='noopener noreferrer'][target='_blank']" do |links|
      viewer, _separator, trace = links.first[:href].partition("?trace=")

      assert_equal "https://traces.example.net/index.html", viewer
      assert_match %r{\Ahttp://ams\.[^/]+/traces/}, CGI.unescape(trace)
    end
  end

  test "merges the trace into a viewer URL that already has a query and a fragment" do
    Upright.configuration.stubs(:trace_viewer_url).returns("https://traces.example.net/?mode=dark#/main")
    attachment = active_storage_attachments(:playwright_trace_artifact)

    get upright.site_artifact_path(attachment)

    assert_response :success
    assert_select "a[rel='noopener noreferrer']" do |links|
      url = URI(links.first[:href])

      assert_match(/\Amode=dark&trace=/, url.query)
      assert_equal "/main", url.fragment
    end
  end

  test "does not serve the trace viewer from the admin origin" do
    get "/trace-viewer/index.html"

    assert_response :not_found
  end

  test "returns 404 for attachments that do not belong to probe results" do
    foreign_attachment = ActiveStorage::Attachment.create!(
      name: "artifacts",
      record: upright_incidents(:upcoming),
      blob: active_storage_blobs(:http_log)
    )

    get upright.site_artifact_path(foreign_attachment)

    assert_response :not_found
  end

  test "redirects to authentication when not signed in" do
    sign_out
    attachment = active_storage_attachments(:http_artifact)

    get upright.site_artifact_path(attachment)

    assert_redirected_to upright.new_admin_session_url(subdomain: "app")
  end
end
