class Upright::AlertmanagerProxyController < Upright::ApplicationController
  include Upright::ProxyAuthentication

  def show
  end

  def proxy
    url = upstream_url(alertmanager_url, request.fullpath.delete_prefix("/alertmanager"))

    if url.nil?
      head :bad_request
    elsif token_forbidden_path?(url.path)
      head :forbidden
    else
      proxy_to_alertmanager url, body: request.body&.read
    end
  end

  private
    def proxy_to_alertmanager(url, method: request.method, body: nil)
      response = Faraday.new(url: alertmanager_url).run_request(method.downcase.to_sym, url.to_s, body, { "Content-Type" => request.content_type })

      render body: response.body, status: response.status, content_type: response.headers["content-type"]
    end

    def alertmanager_url
      ENV.fetch("ALERTMANAGER_URL", "http://localhost:9093")
    end
end
