# Checks the public side of a remote MCP server, the same way an MCP client
# starts a connection before the user signs in:
#
# 1. An unauthenticated `initialize` request to the MCP endpoint returns 401
#    with a `WWW-Authenticate` header that names the resource metadata URL.
# 2. The resource metadata names the configured authorization server and the
#    endpoint itself as the protected resource.
# 3. The authorization server metadata advertises the endpoints a client needs
#    to register and sign in (authorization, token, dynamic client registration).
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

  REQUIRED_AUTHORIZATION_SERVER_KEYS = %w[ authorization_endpoint token_endpoint registration_endpoint ]

  def check
    @log = StringIO.new

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

      challenge = response.headers["WWW-Authenticate"].to_s
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
      metadata = fetch_json("#{authorization_server}/.well-known/oauth-authorization-server")

      expect metadata["issuer"] == authorization_server, "issuer is #{metadata["issuer"].inspect}, expected #{authorization_server}"
      expect Array(metadata["code_challenge_methods_supported"]).include?("S256"), "S256 is not a supported code challenge method"

      REQUIRED_AUTHORIZATION_SERVER_KEYS.each do |key|
        expect metadata[key].present?, "authorization server metadata has no #{key}"
      end
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
