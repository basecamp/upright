require "test_helper"

class TracesControllerTest < ActionDispatch::IntegrationTest
  setup do
    on_subdomain "ams"
    Upright.configuration.stubs(:trace_viewer_url).returns("https://traces.example.net/index.html")
    Upright.configuration.stubs(:trace_viewer_origin).returns("https://traces.example.net")
    @trace = active_storage_attachments(:playwright_trace_artifact)
    # The blob fixture has no bytes behind it, and streaming one that isn't
    # there answers 404 rather than exercising anything.
    @trace.blob.upload(StringIO.new("PK\x03\x04 stand-in for a trace"))
    @trace.blob.save!
  end

  teardown do
    @trace.blob.service.delete(@trace.blob.key)
  end

  test "serves a trace to the viewer origin without a session" do
    get trace_path(@trace)

    assert_response :success
    assert_equal "https://traces.example.net", response.headers["Access-Control-Allow-Origin"]
    assert_equal "Origin", response.headers["Vary"]
  end

  test "answers a range request with the requested bytes" do
    get trace_path(@trace), headers: { "Range" => "bytes=0-3" }

    assert_response :partial_content
    assert_equal 4, response.body.bytesize
    assert_equal "https://traces.example.net", response.headers["Access-Control-Allow-Origin"]
    assert_match "Content-Range", response.headers["Access-Control-Expose-Headers"]
  end

  test "404s when no viewer is configured" do
    Upright.configuration.stubs(:trace_viewer_origin).returns(nil)

    get trace_path(@trace)

    assert_response :not_found
  end

  test "404s a signed id for an artifact that isn't a trace" do
    get trace_path(active_storage_attachments(:http_artifact))

    assert_response :not_found
  end

  test "404s a signed id signed for another purpose" do
    get upright.site_trace_path(signed_id: @trace.signed_id(purpose: :something_else))

    assert_response :not_found
  end

  test "404s a tampered signed id" do
    get upright.site_trace_path(signed_id: "not-a-signed-id")

    assert_response :not_found
  end

  private
    def trace_path(attachment)
      upright.site_trace_path(signed_id: Upright::TracesController.signed_id_for(attachment))
    end
end
