# frozen_string_literal: true

require "test_helper"
require_relative "../../script/release/registry"

require "digest"
require "json"
require "stringio"
require "tmpdir"

# Fixture tests for every transition of the registry state machine. The HTTP
# layer is scripted: each test declares the exact sequence of responses (or
# network faults) the registry will see, and asserts the one defined outcome.
class RegistryTest < ActiveSupport::TestCase
  Registry = Upright::Release::Registry

  NAME = "upright"
  VERSION = "0.1.0"
  BYTES = "canonical gem bytes"
  DIGEST = Digest::SHA256.hexdigest(BYTES)
  OTHER_SHA = ("f" * 64).freeze

  VERSION_URL = "https://rubygems.org/api/v2/rubygems/upright/versions/0.1.0.json"
  GEM_URL = "https://rubygems.org/gems/upright-0.1.0.gem"

  # --- check: the publish job's decision ------------------------------------

  test "check 404 means version absent so push" do
    registry = scripted(res(404))
    assert_equal :push, registry.check(VERSION, DIGEST)
    assert_equal [ VERSION_URL ], @requests
  end

  test "check 200 with our sha means already published so skip" do
    registry = scripted(res(200, version_json))
    assert_equal :skip, registry.check(VERSION, DIGEST)
  end

  test "check normalizes sha case" do
    registry = scripted(res(200, version_json))
    assert_equal :skip, registry.check(VERSION, DIGEST.upcase)
  end

  test "check 200 with different sha fails closed" do
    registry = scripted(res(200, version_json(sha: OTHER_SHA)))
    error = assert_raises(Registry::Error) { registry.check(VERSION, DIGEST) }
    assert_match(/already published/, error.message)
  end

  test "check 200 for a different version fails closed" do
    registry = scripted(res(200, version_json(number: "9.9.9")))
    assert_raises(Registry::Error) { registry.check(VERSION, DIGEST) }
  end

  test "check malformed json fails closed" do
    registry = scripted(res(200, "<html>surprise!</html>"))
    error = assert_raises(Registry::Error) { registry.check(VERSION, DIGEST) }
    assert_match(/malformed JSON/, error.message)
  end

  test "check non hash json fails closed" do
    registry = scripted(res(200, [ 1, 2 ].to_json))
    assert_raises(Registry::Error) { registry.check(VERSION, DIGEST) }
  end

  test "check missing sha fails closed" do
    registry = scripted(res(200, { "number" => VERSION }.to_json))
    assert_raises(Registry::Error) { registry.check(VERSION, DIGEST) }
  end

  test "check unusable sha fails closed" do
    registry = scripted(res(200, version_json(sha: "not-a-digest")))
    assert_raises(Registry::Error) { registry.check(VERSION, DIGEST) }
  end

  test "check rejects invalid input sha" do
    registry = scripted
    assert_raises(Registry::Error) { registry.check(VERSION, "banana") }
    assert_empty @requests
  end

  test "check retries through 429 with backoff" do
    registry = scripted(res(429), res(429), res(404))
    assert_equal :push, registry.check(VERSION, DIGEST)
    assert_equal [ 2, 4 ], @slept
  end

  test "check retries through 5xx and network faults" do
    registry = scripted(res(503), Net::ReadTimeout.new, res(404))
    assert_equal :push, registry.check(VERSION, DIGEST)
  end

  test "check persistent 429 fails after bounded retries" do
    registry = scripted([ res(429) ] * Registry::MAX_ATTEMPTS)
    error = assert_raises(Registry::Error) { registry.check(VERSION, DIGEST) }
    assert_match(/after #{Registry::MAX_ATTEMPTS} attempts/, error.message)
    assert_equal Registry::MAX_ATTEMPTS, @requests.size
  end

  test "check persistent 5xx fails after bounded retries" do
    registry = scripted([ res(500) ] * Registry::MAX_ATTEMPTS)
    assert_raises(Registry::Error) { registry.check(VERSION, DIGEST) }
  end

  test "check persistent network fault fails after bounded retries" do
    registry = scripted([ Net::OpenTimeout.new ] * Registry::MAX_ATTEMPTS)
    assert_raises(Registry::Error) { registry.check(VERSION, DIGEST) }
  end

  test "check unexpected status fails closed without retry" do
    registry = scripted(res(403))
    assert_raises(Registry::Error) { registry.check(VERSION, DIGEST) }
    assert_equal 1, @requests.size
  end

  # --- confirm: bounded poll, then canonical-bytes verification -------------

  test "confirm polls through 404 then verifies canonical bytes" do
    registry = scripted(
      res(404), res(404),
      res(200, version_json),        # poll sees our version + sha
      res(200, version_json),        # verified_download re-reads metadata
      res(200, BYTES)                # canonical bytes
    )
    assert_equal BYTES, registry.confirm(VERSION, DIGEST)
    assert_equal [ VERSION_URL, VERSION_URL, VERSION_URL, VERSION_URL, GEM_URL ], @requests
  end

  test "confirm times out when version never appears" do
    registry = scripted([ res(404) ] * 10)
    error = assert_raises(Registry::Error) { registry.confirm(VERSION, DIGEST, deadline: 12) }
    assert_match(/gave up waiting/, error.message)
  end

  test "confirm fails immediately on different published sha" do
    registry = scripted(res(200, version_json(sha: OTHER_SHA)))
    error = assert_raises(Registry::Error) { registry.confirm(VERSION, DIGEST) }
    assert_match(/stopping for a human/, error.message)
  end

  test "confirm retries malformed bodies within bounds" do
    registry = scripted(
      res(200, "not json"), res(200, "still not json"),
      res(200, version_json),
      res(200, version_json), res(200, BYTES)
    )
    assert_equal BYTES, registry.confirm(VERSION, DIGEST)
  end

  test "confirm fails after persistent malformed bodies" do
    registry = scripted([ res(200, "not json") ] * Registry::MALFORMED_LIMIT)
    error = assert_raises(Registry::Error) { registry.confirm(VERSION, DIGEST) }
    assert_match(/malformed JSON/, error.message)
  end

  test "confirm malformed tolerance is consecutive not cumulative" do
    # MALFORMED_LIMIT malformed bodies arrive, but interleaved with healthy
    # non-malformed outcomes — the counter must reset each time.
    registry = scripted(
      res(200, "not json"), res(404),
      res(200, "not json"), res(503),
      res(200, "not json"), Net::ReadTimeout.new,
      res(200, version_json),
      res(200, version_json), res(200, BYTES)
    )
    assert_equal BYTES, registry.confirm(VERSION, DIGEST)
  end

  test "confirm backs off through 429 5xx and network faults while polling" do
    registry = scripted(
      res(429), res(503), Net::ReadTimeout.new,
      res(200, version_json),
      res(200, version_json), res(200, BYTES)
    )
    assert_equal BYTES, registry.confirm(VERSION, DIGEST)
  end

  test "confirm fails closed on unexpected status while polling" do
    registry = scripted(res(302, "", location: "https://elsewhere.example/"))
    assert_raises(Registry::Error) { registry.confirm(VERSION, DIGEST) }
  end

  test "confirm fails when registry flips sha between poll and download" do
    flipped_bytes = "someone else's bytes"
    flipped = version_json(sha: Digest::SHA256.hexdigest(flipped_bytes))
    registry = scripted(
      res(200, version_json),   # poll: matches ours
      res(200, flipped),        # verified_download: registry now says otherwise
      res(200, flipped_bytes)
    )
    error = assert_raises(Registry::Error) { registry.confirm(VERSION, DIGEST) }
    assert_match(/does not match our artifact digest/, error.message)
  end

  # --- verified_download: the recovery path ---------------------------------

  test "verified download returns bytes and digest" do
    registry = scripted(res(200, version_json), res(200, BYTES))
    assert_equal [ BYTES, DIGEST ], registry.verified_download(VERSION)
    assert_equal [ VERSION_URL, GEM_URL ], @requests
  end

  test "verified download requires the version to be published" do
    registry = scripted(res(404))
    error = assert_raises(Registry::Error) { registry.verified_download(VERSION) }
    assert_match(/expected upright 0\.1\.0 to be published/, error.message)
  end

  test "verified download fails when bytes do not match registry sha" do
    registry = scripted(res(200, version_json), res(200, "tampered bytes"))
    error = assert_raises(Registry::Error) { registry.verified_download(VERSION) }
    assert_match(/does not match registry-reported/, error.message)
  end

  test "verified download follows https redirects" do
    registry = scripted(
      res(200, version_json),
      res(302, "", location: "https://cdn.example/upright-0.1.0.gem"),
      res(200, BYTES)
    )
    assert_equal [ BYTES, DIGEST ], registry.verified_download(VERSION)
    assert_equal "https://cdn.example/upright-0.1.0.gem", @requests.last
  end

  test "verified download bounds redirects" do
    hops = [ res(200, version_json) ]
    (Registry::MAX_REDIRECTS + 1).times { hops << res(301, "", location: "https://cdn.example/hop") }
    registry = scripted(hops)
    error = assert_raises(Registry::Error) { registry.verified_download(VERSION) }
    assert_match(/too many redirects/, error.message)
  end

  test "verified download resolves relative redirects against the current uri" do
    registry = scripted(
      res(200, version_json),
      res(302, "", location: "/downloads/upright-0.1.0.gem"),
      res(200, BYTES)
    )
    assert_equal [ BYTES, DIGEST ], registry.verified_download(VERSION)
    assert_equal "https://rubygems.org/downloads/upright-0.1.0.gem", @requests.last
  end

  test "verified download resolves scheme relative redirects as https" do
    registry = scripted(
      res(200, version_json),
      res(302, "", location: "//cdn.example/upright-0.1.0.gem"),
      res(200, BYTES)
    )
    assert_equal [ BYTES, DIGEST ], registry.verified_download(VERSION)
    assert_equal "https://cdn.example/upright-0.1.0.gem", @requests.last
  end

  test "verified download rejects unparseable redirect location" do
    registry = scripted(res(200, version_json), res(302, "", location: "http://["))
    error = assert_raises(Registry::Error) { registry.verified_download(VERSION) }
    assert_match(/unusable redirect location/, error.message)
  end

  test "verified download rejects redirect without location" do
    registry = scripted(res(200, version_json), res(302, ""))
    assert_raises(Registry::Error) { registry.verified_download(VERSION) }
  end

  test "verified download rejects redirect with empty location" do
    registry = scripted(res(200, version_json), res(302, "", location: ""))
    assert_raises(Registry::Error) { registry.verified_download(VERSION) }
  end

  test "verified download rejects non https redirect" do
    registry = scripted(res(200, version_json), res(302, "", location: "http://cdn.example/gem"))
    error = assert_raises(Registry::Error) { registry.verified_download(VERSION) }
    assert_match(/non-https/, error.message)
  end

  test "verified download fails closed on unexpected download status" do
    registry = scripted(res(200, version_json), res(403))
    assert_raises(Registry::Error) { registry.verified_download(VERSION) }
  end

  # --- CLI entry points ------------------------------------------------------

  test "run check prints the decision and exits zero" do
    registry = scripted(res(404))
    out, err = capture
    status = Registry.run_check([ NAME, VERSION, DIGEST ], out: out, err: err, registry_for: for_name(registry))
    assert_equal 0, status
    assert_equal "push\n", out.string
  end

  test "run check usage error exits two" do
    out, err = capture
    status = Registry.run_check([ NAME ], out: out, err: err, registry_for: for_name(scripted))
    assert_equal 2, status
    assert_match(/usage/, err.string)
    assert_empty @requests
  end

  test "run check failure exits one" do
    registry = scripted(res(200, version_json(sha: OTHER_SHA)))
    out, err = capture
    status = Registry.run_check([ NAME, VERSION, DIGEST ], out: out, err: err, registry_for: for_name(registry))
    assert_equal 1, status
    assert_match(/registry check failed/, err.string)
  end

  test "run confirm succeeds without explicit deadline" do
    registry = scripted(res(200, version_json), res(200, version_json), res(200, BYTES))
    out, err = capture
    status = Registry.run_confirm([ NAME, VERSION, DIGEST ], out: out, err: err, registry_for: for_name(registry))
    assert_equal 0, status
    assert_match(/confirmed/, out.string)
  end

  test "run confirm accepts a numeric deadline" do
    registry = scripted(res(200, version_json), res(200, version_json), res(200, BYTES))
    out, err = capture
    status = Registry.run_confirm([ NAME, VERSION, DIGEST, "60" ], out: out, err: err, registry_for: for_name(registry))
    assert_equal 0, status
  end

  test "run confirm rejects a malformed deadline" do
    out, err = capture
    status = Registry.run_confirm([ NAME, VERSION, DIGEST, "soonish" ], out: out, err: err, registry_for: for_name(scripted))
    assert_equal 2, status
    assert_match(/usage/, err.string)
  end

  test "run confirm rejects too many arguments" do
    out, err = capture
    status = Registry.run_confirm([ NAME, VERSION, DIGEST, "60", "extra" ], out: out, err: err, registry_for: for_name(scripted))
    assert_equal 2, status
  end

  test "run confirm failure exits one" do
    registry = scripted(res(200, version_json(sha: OTHER_SHA)))
    out, err = capture
    status = Registry.run_confirm([ NAME, VERSION, DIGEST ], out: out, err: err, registry_for: for_name(registry))
    assert_equal 1, status
    assert_match(/registry confirmation failed/, err.string)
  end

  test "run download writes the file and prints the digest" do
    registry = scripted(res(200, version_json), res(200, BYTES))
    out, err = capture
    Dir.mktmpdir do |dir|
      destination = File.join(dir, "upright-0.1.0.gem")
      status = Registry.run_download([ NAME, VERSION, destination ], out: out, err: err, registry_for: for_name(registry))
      assert_equal 0, status
      assert_equal BYTES, File.binread(destination)
      assert_equal "#{DIGEST}\n", out.string
    end
  end

  test "run download usage error exits two" do
    out, err = capture
    status = Registry.run_download([ NAME, VERSION ], out: out, err: err, registry_for: for_name(scripted))
    assert_equal 2, status
    assert_match(/usage/, err.string)
  end

  test "run download failure exits one" do
    registry = scripted(res(404))
    out, err = capture
    Dir.mktmpdir do |dir|
      status = Registry.run_download([ NAME, VERSION, File.join(dir, "x.gem") ], out: out, err: err, registry_for: for_name(registry))
      assert_equal 1, status
      assert_match(/registry download failed/, err.string)
    end
  end

  private
    # Build a registry whose HTTP layer replays exactly these steps: a
    # Response is returned, an Exception is raised. Sleeps advance the fake
    # clock so deadline behavior is testable.
    def scripted(*steps)
      @requests = []
      @slept = []
      @now = 0.0
      queue = steps.flatten

      http = lambda do |uri|
        @requests << uri.to_s
        raise "HTTP script exhausted at request #{@requests.size}: #{uri}" if queue.empty?
        step = queue.shift
        step.is_a?(Exception) ? raise(step) : step
      end

      Registry.new(
        NAME,
        http: http,
        sleeper: lambda { |seconds|
          @slept << seconds
          @now += seconds
        },
        clock: -> { @now }
      )
    end

    def res(status, body = "", location: nil)
      Registry::Response.new(status, body, location)
    end

    def version_json(number: VERSION, sha: DIGEST)
      { "number" => number, "sha" => sha }.to_json
    end

    def capture
      [ StringIO.new, StringIO.new ]
    end

    def for_name(registry)
      lambda { |name|
        assert_equal NAME, name
        registry
      }
    end
end
