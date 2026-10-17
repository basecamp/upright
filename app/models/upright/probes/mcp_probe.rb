# Checks the public side of a remote MCP server, the same way an MCP client
# starts a connection before the user signs in:
#
# 1. An unauthenticated `initialize` request to the MCP endpoint returns 401
#    with a `WWW-Authenticate` header that names the resource metadata URL.
# 2. The resource metadata names the configured authorization server and the
#    endpoint itself as the protected resource.
# 3. The authorization server metadata advertises the endpoints a client needs
#    to sign in (authorization, token, S256), and each way of registering a
#    client that `client_registration` names: dynamic client registration
#    (RFC 7591) by default, client ID metadata documents, both, or neither.
class Upright::Probes::MCPProbe < FrozenRecord::Base
  include Upright::Probeable
  include Upright::ProbeYamlSource

  stagger_by_site 3.seconds

  class CheckFailed < StandardError; end

  INITIALIZE_REQUEST = {
    jsonrpc: "2.0",
    id: 1,
    method: "initialize",
    params: {
      protocolVersion: "2025-06-18",
      capabilities: {},
      clientInfo: { name: "upright", version: "1.0" }
    }
  }.to_json

  REQUIRED_AUTHORIZATION_SERVER_KEYS = %w[ authorization_endpoint token_endpoint ]
  CLIENT_REGISTRATIONS = %w[ dynamic metadata_document ]

  def check
    @log = StringIO.new

    verify_client_registration_option
    resource_metadata_url = discover_resource_metadata_url
    verify_resource_metadata(resource_metadata_url)
    verify_authorization_server_metadata

    true
  rescue CheckFailed => error
    log "FAILED: #{error.message}"
    false
  end

  def on_check_recorded(probe_result)
    if @log
      Upright::Artifact.new(name: "mcp.log", content: @log.string).attach_to(probe_result)
    end
  end

  def probe_type = "mcp"
  def probe_target = url

  private
    def discover_resource_metadata_url
      response = request(:post, url, body: INITIALIZE_REQUEST, headers: {
        "Content-Type" => "application/json",
        "Accept" => "application/json, text/event-stream"
      })

      expect response.code == 401, "initialize without a token returned #{response.code}, expected 401"

      challenge = Array(response.headers["WWW-Authenticate"]).join(", ")
      resource_metadata_url = challenge[/resource_metadata="([^"]+)"/, 1]
      expect resource_metadata_url, "401 response has no resource_metadata in WWW-Authenticate: #{challenge.inspect}"

      uri = URI.parse(resource_metadata_url)
      expect uri.scheme == "https" && uri.host == URI.parse(url).host,
        "resource_metadata URL #{resource_metadata_url} is not an https URL on #{URI.parse(url).host}"

      resource_metadata_url
    end

    def verify_resource_metadata(resource_metadata_url)
      metadata = fetch_json(resource_metadata_url)

      expect metadata["resource"] == url, "resource is #{metadata["resource"].inspect}, expected #{url}"
      expect Array(metadata["authorization_servers"]).include?(authorization_server),
        "authorization_servers #{metadata["authorization_servers"].inspect} does not include #{authorization_server}"
    end

    def verify_authorization_server_metadata
      metadata = fetch_json(authorization_server_metadata_url)

      expect metadata["issuer"] == authorization_server, "issuer is #{metadata["issuer"].inspect}, expected #{authorization_server}"
      expect Array(metadata["code_challenge_methods_supported"]).include?("S256"), "S256 is not a supported code challenge method"

      REQUIRED_AUTHORIZATION_SERVER_KEYS.each do |key|
        expect metadata[key].present?, "authorization server metadata has no #{key}"
      end

      verify_client_registration(metadata)
    end

    def verify_client_registration(metadata)
      if client_registrations.include?("dynamic")
        expect metadata["registration_endpoint"].present?, "authorization server metadata has no registration_endpoint"
      end

      if client_registrations.include?("metadata_document")
        expect metadata["client_id_metadata_document_supported"] == true,
          "authorization server metadata does not set client_id_metadata_document_supported to true"
      end
    end

    def verify_client_registration_option
      unknown = client_registrations - CLIENT_REGISTRATIONS
      expect unknown.empty?, "client_registration #{unknown.inspect} is not one of #{CLIENT_REGISTRATIONS.inspect}"
    end

    # The ways of registering a client the authorization server must advertise.
    # Unset means dynamic client registration; an empty list requires none, for
    # a server whose clients are all registered ahead of time.
    def client_registrations
      self[:client_registration].nil? ? %w[ dynamic ] : Array(self[:client_registration]).map(&:to_s)
    end

    # RFC 8414: the well-known segment goes between the host and the issuer's path.
    def authorization_server_metadata_url
      issuer = URI.parse(authorization_server)

      "#{issuer.origin}/.well-known/oauth-authorization-server#{issuer.path.chomp("/")}"
    end

    def fetch_json(json_url)
      response = request(:get, json_url, headers: { "Accept" => "application/json" })
      expect response.code == 200, "GET #{json_url} returned #{response.code}, expected 200"

      JSON.parse(response.body).tap do |parsed|
        expect parsed.is_a?(Hash), "GET #{json_url} did not return a JSON object"
      end
    rescue JSON::ParserError => error
      raise CheckFailed, "GET #{json_url} returned invalid JSON: #{error.message}"
    end

    def request(method, request_url, **options)
      timeout = Upright.current_site.default_timeout

      response = Typhoeus::Request.new(request_url,
        method: method,
        timeout: timeout,
        connecttimeout: timeout,
        forbid_reuse: true,
        headers: { "User-Agent" => Upright.configuration.user_agent }.merge(options.fetch(:headers, {})),
        body: options[:body]
      ).run

      log "#{method.to_s.upcase} #{request_url} -> #{response.code}"
      response.headers&.each { |name, value| log "< #{name}: #{value}" if name.casecmp?("www-authenticate") }

      expect !response.timed_out? && response.code != 0, "#{method.to_s.upcase} #{request_url} failed: #{response.return_message}"

      response
    end

    def expect(condition, message)
      raise CheckFailed, message unless condition
    end

    def log(message)
      @log.puts message
    end
end
