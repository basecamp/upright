module Upright::ArtifactsHelper
  def trace?(artifact)
    artifact.filename.to_s.end_with?(".zip")
  end

  # nil unless an isolated viewer origin is configured, since rendering a trace
  # on Upright's own origin executes its contents there.
  def trace_viewer_url_for(artifact)
    viewer = Upright.configuration.trace_viewer_url
    return if viewer.blank?

    trace = main_app.rails_blob_url(artifact, disposition: :inline, expires_in: 24.hours, host: request.host)
    "#{viewer}?trace=#{CGI.escape(trace)}"
  end
end
