require "test_helper"

class Upright::HTTP::RequestTest < ActiveSupport::TestCase
  setup do
    set_test_site
  end

  test "redacts credentials from the verbose log" do
    stub_typhoeus_response debug_info: stub(
      text: [ "Connected to example.com\n" ],
      header_out: [ "GET / HTTP/1.1\r\nHost: example.com\r\nAuthorization: Basic dXNlcjpwYXNz\r\nProxy-Authorization: Basic cHJveHlzZWNyZXQ=\r\nCookie: session=topsecret\r\nAccept: */*\r\n\r\n" ],
      header_in: [ "HTTP/1.1 200 OK\r\n", "Set-Cookie: session=newsecret; HttpOnly\r\n", "Content-Type: text/html\r\n" ]
    )

    log = Upright::HTTP::Request.new("https://example.com/", username: "user", password: "pass").get.verbose_log_content

    assert_no_match(/dXNlcjpwYXNz/, log)
    assert_no_match(/cHJveHlzZWNyZXQ=/, log)
    assert_no_match(/topsecret/, log)
    assert_no_match(/newsecret/, log)
    assert_match(/Authorization:\s*\[REDACTED\]/, log)
    assert_match(/Proxy-Authorization:\s*\[REDACTED\]/, log)
    assert_match(/Cookie:\s*\[REDACTED\]/, log)
    assert_match(/Set-Cookie:\s*\[REDACTED\]/, log)
  end

  test "redacts sensitive headers case-insensitively and with leading whitespace" do
    stub_typhoeus_response debug_info: stub(
      text: [],
      header_out: [ "  authorization: Bearer sekrit-token\r\nCOOKIE: session=hushhush\r\n" ],
      header_in: [ "set-cookie: _app=covert\r\n" ]
    )

    log = Upright::HTTP::Request.new("https://example.com/").get.verbose_log_content

    assert_no_match(/sekrit-token/, log)
    assert_no_match(/hushhush/, log)
    assert_no_match(/covert/, log)
  end

  test "redacts userpwd credential lines" do
    stub_typhoeus_response debug_info: stub(
      text: [ "userpwd: user:hunter2\n" ],
      header_out: [],
      header_in: []
    )

    log = Upright::HTTP::Request.new("https://example.com/").get.verbose_log_content

    assert_no_match(/hunter2/, log)
  end

  test "leaves ordinary headers intact" do
    stub_typhoeus_response debug_info: stub(
      text: [ "Connected to example.com\n" ],
      header_out: [ "GET / HTTP/1.1\r\nHost: example.com\r\nAccept: */*\r\n\r\n" ],
      header_in: [ "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n" ]
    )

    log = Upright::HTTP::Request.new("https://example.com/").get.verbose_log_content

    assert_match(/Host: example.com/, log)
    assert_match(/Content-Type: text\/html/, log)
    assert_match(/Connected to example.com/, log)
  end

  private
    def stub_typhoeus_response(debug_info:)
      Typhoeus::Response.new(code: 200).tap do |response|
        response.stubs(:debug_info).returns(debug_info)
        Typhoeus.stubs(:get).returns(response)
      end
    end
end
