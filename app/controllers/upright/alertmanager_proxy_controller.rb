class Upright::AlertmanagerProxyController < Upright::ApplicationController
  include Upright::ProxyAuthentication

  skip_forgery_protection

  def show
  end

  def proxy
    forward = sanitized_upstream_path(request.fullpath.delete_prefix("/alertmanager"))
    path = forward&.split("?", 2)&.first

    if forward.nil? || !upstream_host_ok?(alertmanager_url, forward)
      head :bad_request
    elsif token_forbidden_path?(path)
      head :forbidden
    else
      proxy_to_alertmanager forward, body: request.body&.read
    end
  end

  private
    def proxy_to_alertmanager(path, method: request.method, body: nil)
      response = Faraday.new(url: alertmanager_url).run_request(method.downcase.to_sym, path, body, { "Content-Type" => request.content_type })

      render body: response.body, status: response.status, content_type: response.headers["content-type"]
    end

    def alertmanager_url
      ENV.fetch("ALERTMANAGER_URL", "http://localhost:9093")
    end
end
