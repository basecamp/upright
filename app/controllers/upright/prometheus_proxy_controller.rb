class Upright::PrometheusProxyController < Upright::ApplicationController
  include Upright::ProxyAuthentication

  skip_before_action :authenticate_user, only: :otlp
  skip_before_action :block_cross_site_session_requests, only: :otlp
  before_action :authenticate_proxy_token, only: :otlp

  UNSUPPORTED_PATHS = %w[/api/v1/notifications]

  def show
  end

  def proxy
    url = upstream_url(Upright.configuration.prometheus_url, request.fullpath.delete_prefix("/prometheus"))

    if url.nil?
      head :bad_request
    elsif url.path.start_with?(*UNSUPPORTED_PATHS)
      head :not_found
    elsif token_forbidden_path?(url.path)
      head :forbidden
    else
      proxy_to_prometheus(url)
    end
  end

  def otlp
    response = prometheus_connection.post("/api/v1/otlp/v1/metrics") do |req|
      req.headers["Content-Type"] = request.content_type
      req.body = request.body.read
    end

    render body: response.body, status: response.status, content_type: response.headers["content-type"]
  end

  private
    def proxy_to_prometheus(url, method: request.method, body: nil)
      response = prometheus_connection.run_request(
        method.downcase.to_sym,
        url.to_s,
        body,
        { "Content-Type" => request.content_type }
      )

      if response.status.in?([ 301, 302 ]) && response.headers["location"]
        redirect_to "/prometheus#{response.headers['location']}", status: response.status, allow_other_host: true
      else
        render body: response.body, status: response.status, content_type: response.headers["content-type"]
      end
    end

    def prometheus_connection
      @prometheus_connection ||= Faraday.new(url: Upright.configuration.prometheus_url) do |f|
        f.options.timeout = 30
      end
    end
end
