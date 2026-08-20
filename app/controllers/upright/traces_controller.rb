# Unauthenticated by design: the configured trace viewer fetches from its own
# origin, so a purpose-scoped signed id stands in for the admin session.
class Upright::TracesController < Upright::ApplicationController
  include ActiveStorage::Streaming
  include ActiveStorage::DisableSession

  PURPOSE = :upright_trace
  EXPIRES_IN = 24.hours

  skip_before_action :authenticate_user

  before_action :allow_trace_viewer_origin
  before_action :answer_preflight, if: -> { request.options? }
  before_action :set_trace

  def self.signed_id_for(attachment)
    attachment.signed_id(purpose: PURPOSE, expires_in: EXPIRES_IN)
  end

  def show
    if request.headers["Range"].present?
      send_blob_byte_range_data @trace, request.headers["Range"]
    else
      send_whole_trace
    end
  end

  private
    def allow_trace_viewer_origin
      origin = Upright.configuration.trace_viewer_origin
      return head :not_found if origin.blank?

      response.headers["Access-Control-Allow-Origin"] = origin
      response.headers["Access-Control-Expose-Headers"] = "Accept-Ranges, Content-Range"
      response.headers["Vary"] = "Origin"
    end

    def answer_preflight
      response.headers["Access-Control-Allow-Methods"] = "GET, HEAD, OPTIONS"
      response.headers["Access-Control-Allow-Headers"] = request.headers["Access-Control-Request-Headers"].to_s
      response.headers["Access-Control-Max-Age"] = 1.day.to_i.to_s
      response.headers["Vary"] = "Origin, Access-Control-Request-Headers"

      head :no_content
    end

    def send_whole_trace
      expires_in EXPIRES_IN, public: false
      response.headers["Accept-Ranges"] = "bytes"
      response.headers["Content-Length"] = @trace.byte_size.to_s

      send_blob_stream @trace
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
