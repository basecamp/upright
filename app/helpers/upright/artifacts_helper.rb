module Upright::ArtifactsHelper
  def trace?(artifact)
    artifact.filename.to_s.end_with?(".zip")
  end

  # nil unless an isolated viewer origin is configured, since rendering a trace
  # on Upright's own origin executes its contents there.
  def trace_viewer_url_for(artifact)
    viewer = Upright.configuration.trace_viewer_url
    return if viewer.blank?

    "#{viewer}?trace=#{CGI.escape(trace_url_for(artifact))}"
  end

  private
    def trace_url_for(artifact)
      site_trace_url(signed_id: Upright::TracesController.signed_id_for(artifact), host: request.host)
    end
end
