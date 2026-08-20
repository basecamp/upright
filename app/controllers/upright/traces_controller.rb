class Upright::TracesController < Upright::ApplicationController
  include ActiveStorage::DisableSession

  PURPOSE = :upright_trace
  EXPIRES_IN = 24.hours

  skip_before_action :authenticate_user
  skip_forgery_protection

  before_action :allow_trace_viewer_origin
  before_action :answer_preflight, if: -> { request.options? }
  before_action :set_trace

  def self.signed_id_for(attachment)
    attachment.signed_id(purpose: PURPOSE, expires_in: EXPIRES_IN)
  end

  def show
    expires_in EXPIRES_IN, public: false
    response.headers["Accept-Ranges"] = "bytes"

    if request.head?
      send_trace_size
    elsif (range = request.headers["Range"]).present?
      send_trace_range range
    else
      send_trace @trace.download
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

    def send_trace_size
      response.headers["Content-Length"] = @trace.byte_size.to_s
      response.headers["Content-Type"] = @trace.content_type_for_serving

      head :ok
    end

    def send_trace_range(header)
      ranges = Rack::Utils.get_byte_ranges(header, @trace.byte_size)
      return head :range_not_satisfiable unless ranges&.one?

      range = ranges.first
      response.headers["Content-Range"] = "bytes #{range.begin}-#{range.end}/#{@trace.byte_size}"

      send_trace @trace.download_chunk(range), status: :partial_content
    end

    def send_trace(data, status: :ok)
      send_data data,
        status: status,
        type: @trace.content_type_for_serving,
        disposition: :inline,
        filename: @trace.filename.sanitized
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
