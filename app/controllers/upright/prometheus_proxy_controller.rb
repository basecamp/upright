class Upright::PrometheusProxyController < Upright::ApplicationController
  skip_forgery_protection

  skip_before_action :authenticate_user, only: :otlp
  before_action :authenticate_otlp_token, only: :otlp

  UNSUPPORTED_PATHS = %w[/api/v1/notifications]

  def show
  end

  def proxy
    path = request.fullpath.sub(%r{^/prometheus}, "")

    if path.start_with?(*UNSUPPORTED_PATHS)
      head :not_found
    else
      proxy_to_prometheus(path)
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
    def proxy_to_prometheus(path, method: request.method, body: nil)
      response = prometheus_connection.run_request(
        method.downcase.to_sym,
        path,
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

    def authenticate_otlp_token
      authenticate_or_request_with_http_token do |token|
        ActiveSupport::SecurityUtils.secure_compare(token, ENV.fetch("PROMETHEUS_OTLP_TOKEN", ""))
      end
    end
end
