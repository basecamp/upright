module Upright::ArtifactsHelper
  def trace?(artifact)
    artifact.filename.to_s.end_with?(".zip")
  end

  def trace_viewer_url_for(artifact)
    viewer = Upright.configuration.trace_viewer_url
    return if viewer.blank?

    URI(viewer).tap do |url|
      query = Rack::Utils.parse_query(url.query).except("trace")
      url.query = query.merge("trace" => trace_url_for(artifact)).to_query
    end.to_s
  end

  private
    def trace_url_for(artifact)
      site_trace_url(signed_id: Upright::TracesController.signed_id_for(artifact), host: request.host)
    end
end
