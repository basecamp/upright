# Serves a trace to the viewer configured in config.trace_viewer_url. The viewer
# fetches from its own origin, so the request carries no session and needs a CORS
# header to be readable at all. The signed id is the capability in its place:
# purpose-scoped, expiring, and only resolvable to a probe result's trace.
class Upright::TracesController < Upright::ApplicationController
  include ActiveStorage::Streaming

  PURPOSE = :upright_trace
  EXPIRES_IN = 24.hours

  skip_before_action :authenticate_user

  before_action :allow_trace_viewer_origin
  before_action :set_trace

  # ActiveStorage::Attachment#signed_id delegates to its blob, so the signature
  # covers the blob and the scope check below is what ties it to a probe result.
  def self.signed_id_for(attachment)
    attachment.signed_id(purpose: PURPOSE, expires_in: EXPIRES_IN)
  end

  def show
    if request.headers["Range"].present?
      send_blob_byte_range_data @trace, request.headers["Range"]
    else
      send_blob_stream @trace
    end
  end

  private
    # No viewer configured, no unauthenticated trace route.
    def allow_trace_viewer_origin
      origin = Upright.configuration.trace_viewer_origin
      return head :not_found if origin.blank?

      response.headers["Access-Control-Allow-Origin"] = origin
      # The viewer reads a ZIP's central directory over range requests, so it
      # needs the ranges it got back, not just the bytes.
      response.headers["Access-Control-Expose-Headers"] = "Accept-Ranges, Content-Range"
      response.headers["Vary"] = "Origin"
    end

    def set_trace
      @trace = ActiveStorage::Blob.find_signed(params[:signed_id], purpose: PURPOSE)

      head :not_found unless @trace && probe_result_trace?
    end

    def probe_result_trace?
      @trace.filename.to_s.end_with?(".zip") &&
        @trace.attachments.exists?(record_type: "Upright::ProbeResult")
    end
end
