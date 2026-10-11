require "test_helper"

class Upright::Probes::MCPProbeTest < ActiveSupport::TestCase
  MCP_URL = "https://mcp.example.com/mcp"
  AUTH_SERVER = "https://app.example.com"
  METADATA_URL = "https://mcp.example.com/.well-known/oauth-protected-resource/mcp"

  setup do
    @probe = Upright::Probes::MCPProbe.new(name: "test", url: MCP_URL, authorization_server: AUTH_SERVER)
  end

  test "probes are configured" do
    probe = Upright::Probes::MCPProbe.first

    assert probe.name.present?
    assert_equal "mcp", probe.probe_type
    assert_equal probe.url, probe.probe_target
    assert probe.authorization_server.present?
  end

  test "passes when the endpoint, resource metadata and authorization server are all healthy" do
    stub_all

    assert @probe.check
  end

  test "fails when the endpoint accepts an unauthenticated request" do
    stub_mcp(status: 200, headers: {})

    assert_not @probe.check
    assert_log "returned 200, expected 401"
  end

  test "fails when the 401 does not name the resource metadata" do
    stub_mcp(headers: { "WWW-Authenticate" => "Bearer" })

    assert_not @probe.check
    assert_log "no resource_metadata"
  end

  test "fails when the resource metadata is on another host" do
    stub_mcp(headers: { "WWW-Authenticate" => %(Bearer resource_metadata="https://evil.example.net/meta") })

    assert_not @probe.check
    assert_log "is not an https URL on mcp.example.com"
  end

  test "fails when the resource metadata names a different authorization server" do
    stub_mcp
    stub_json(METADATA_URL, resource: MCP_URL, authorization_servers: [ "https://other.example.com" ])

    assert_not @probe.check
    assert_log "does not include #{AUTH_SERVER}"
  end

  test "fails when the authorization server cannot register clients" do
    stub_mcp
    stub_json(METADATA_URL, resource: MCP_URL, authorization_servers: [ AUTH_SERVER ])
    stub_json("#{AUTH_SERVER}/.well-known/oauth-authorization-server", authorization_server_metadata.except(:registration_endpoint))

    assert_not @probe.check
    assert_log "no registration_endpoint"
  end

  test "fails when the endpoint times out" do
    stub_request(:post, MCP_URL).to_timeout

    assert_not @probe.check
  end

  test "fails when a metadata document is not JSON" do
    stub_mcp
    stub_request(:get, METADATA_URL).to_return(status: 200, body: "<html>")

    assert_not @probe.check
    assert_log "invalid JSON"
  end

  private
    def stub_all
      stub_mcp
      stub_json(METADATA_URL, resource: MCP_URL, authorization_servers: [ AUTH_SERVER ])
      stub_json("#{AUTH_SERVER}/.well-known/oauth-authorization-server", authorization_server_metadata)
    end

    def stub_mcp(status: 401, headers: { "WWW-Authenticate" => %(Bearer resource_metadata="#{METADATA_URL}") })
      stub_request(:post, MCP_URL).to_return(status:, headers:, body: "{}")
    end

    def stub_json(url, body)
      stub_request(:get, url).to_return(status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" })
    end

    def authorization_server_metadata
      {
        issuer: AUTH_SERVER,
        authorization_endpoint: "#{AUTH_SERVER}/oauth/authorize",
        token_endpoint: "#{AUTH_SERVER}/oauth/token",
        registration_endpoint: "#{AUTH_SERVER}/oauth/clients",
        code_challenge_methods_supported: [ "S256" ]
      }
    end

    def assert_log(fragment)
      assert_includes @probe.instance_variable_get(:@log).string, fragment
    end
end
