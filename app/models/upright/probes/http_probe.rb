class Upright::Probes::HTTPProbe < FrozenRecord::Base
  include Upright::Probeable
  include Upright::ProbeYamlSource

  stagger_by_site 3.seconds

  DEFAULT_EXPECTED_STATUS = 200..399

  # Response bodies are stored as viewable/downloadable artifacts: cap their
  # size and never store them as text/html, which would be same-origin XSS.
  MAX_STORED_BODY_BYTES = 1.megabyte
  TRUNCATION_NOTICE = "\n\n[TRUNCATED: response body exceeded #{MAX_STORED_BODY_BYTES} bytes]".freeze

  attr_accessor :last_response

  def check
    self.last_response = perform_request
    record_response_status
    status_matches_expected?
  end

  def on_check_recorded(probe_result)
    attach_verbose_log(probe_result)
    attach_response_body(probe_result)
  end

  def probe_type = "http"
  def probe_target = url

  private
    def perform_request
      Upright::HTTP::Request.new(url, **request_options).get
    end

    def request_options
      credentials_hash.merge(proxy_hash)
    end

    def status_matches_expected?
      if last_response.network_error?
        false
      else
        last_response.status_in?(expected_status_range)
      end
    end

    def expected_status_range
      if try(:expected_status).is_a?(Integer)
        expected_status..expected_status
      else
        DEFAULT_EXPECTED_STATUS
      end
    end

    def credentials_hash
      if credentials
        { username: credentials[:username], password: credentials[:password] }
      else
        {}
      end
    end

    def credentials
      if try(:basic_auth_credentials)
        Rails.application.credentials.dig(:http_probes, basic_auth_credentials.to_sym)
      end
    end

    def proxy_hash
      if proxy_credentials
        {
          proxy: proxy_credentials[:url],
          proxy_username: proxy_credentials[:username],
          proxy_password: proxy_credentials[:password]
        }.compact
      else
        {}
      end
    end

    def proxy_credentials
      if selected_proxy
        Rails.application.credentials.dig(:proxies, selected_proxy.to_sym)
      end
    end

    def selected_proxy
      Array(try(:proxies) || try(:proxy)).sample
    end

    def record_response_status
      if last_response && !last_response.network_error? && defined?(Yabeda)
        Yabeda.upright_http_response_status.set(
          { name: probe_name, probe_target: probe_target, probe_service: probe_service },
          last_response.status
        )
      end
    end

    def attach_verbose_log(probe_result)
      if last_response
        Upright::Artifact.new(name: "curl.log", content: last_response.verbose_log_content).attach_to(probe_result)
      end
    end

    def attach_response_body(probe_result)
      if last_response && last_response.body.present?
        # Attach directly with identify: false — the body is untrusted remote
        # content, and ActiveStorage's content sniffing would otherwise restore
        # text/html and make the stored artifact same-origin XSS when previewed.
        probe_result.artifacts.attach(
          io: StringIO.new(stored_body),
          filename: "response.#{stored_body_extension}",
          content_type: stored_body_content_type,
          identify: false
        )
      end
    end

    def stored_body_extension
      last_response.file_extension == "html" ? "txt" : last_response.file_extension
    end

    def stored_body_content_type
      Marcel::MimeType.for(extension: stored_body_extension)
    end

    def stored_body
      if last_response.body.bytesize > MAX_STORED_BODY_BYTES
        last_response.body.byteslice(0, MAX_STORED_BODY_BYTES) + TRUNCATION_NOTICE
      else
        last_response.body
      end
    end
end
