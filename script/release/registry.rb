# frozen_string_literal: true

require "digest"
require "json"
require "net/http"
require "uri"

module Upright
  module Release
    # Talks to the RubyGems API about one gem version and answers with a total
    # state machine: every response maps to push, skip, keep-waiting, or fail
    # closed. No error-string matching anywhere — this reconciliation is the
    # release pipeline's idempotency mechanism.
    #
    # Standard library only: the jobs that run it have no bundle and (publish/
    # confirm) no checkout, receiving these scripts via a build artifact.
    class Registry
      # Fail closed. Every path that is not one of the explicitly defined
      # proceed/skip/keep-waiting transitions raises this.
      class Error < StandardError; end

      # Internal: a condition worth retrying (429, 5xx, network fault) — never
      # escapes; it either resolves within bounds or becomes an Error.
      class RetryableFault < StandardError; end

      HOST = "https://rubygems.org"
      MAX_ATTEMPTS = 5      # bounded retries for 429/5xx/network faults
      MALFORMED_LIMIT = 3   # consecutive malformed bodies tolerated while polling
      BACKOFF_BASE = 2      # seconds; fault n backs off BACKOFF_BASE * n
      POLL_INTERVAL = 5     # seconds between polls while the version is absent
      CONFIRM_DEADLINE = 300
      MAX_REDIRECTS = 3
      OPEN_TIMEOUT = 10
      READ_TIMEOUT = 30

      Response = Struct.new(:status, :body, :location)

      # Live wiring, exercised only against the real registry; tests inject
      # all three dependencies.
      def self.live(name)
        new(
          name,
          http: lambda do |uri|
            response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                       open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
              http.request(Net::HTTP::Get.new(uri))
            end
            Response.new(response.code.to_i, response.body.to_s, response["location"])
          end,
          sleeper: ->(seconds) { Kernel.sleep(seconds) },
          clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
        )
      end

      # CLI entry points, one per pipeline job; each returns a process exit
      # status. The registry_* executables are one-line wrappers around these.
      def self.run_check(argv, out: $stdout, err: $stderr, registry_for: method(:live))
        name, version, sha256 = argv
        if argv.size != 3
          err.puts "usage: registry_check.rb NAME VERSION SHA256"
          return 2
        end

        out.puts registry_for.call(name).check(version, sha256)
        0
      rescue Error => e
        err.puts "registry check failed: #{e.message}"
        1
      end

      def self.run_confirm(argv, out: $stdout, err: $stderr, registry_for: method(:live))
        name, version, sha256, deadline = argv
        if argv.size < 3 || argv.size > 4 || (deadline && !deadline.match?(/\A\d+\z/))
          err.puts "usage: registry_confirm.rb NAME VERSION SHA256 [DEADLINE_SECONDS]"
          return 2
        end

        registry = registry_for.call(name)
        registry.confirm(version, sha256, deadline: (deadline || CONFIRM_DEADLINE).to_i)
        out.puts "confirmed: #{name} #{version} is live with sha256 #{sha256.downcase}"
        0
      rescue Error => e
        err.puts "registry confirmation failed: #{e.message}"
        1
      end

      def self.run_download(argv, out: $stdout, err: $stderr, registry_for: method(:live))
        name, version, destination = argv
        if argv.size != 3
          err.puts "usage: registry_download.rb NAME VERSION DESTINATION"
          return 2
        end

        bytes, digest = registry_for.call(name).verified_download(version)
        File.binwrite(destination, bytes)
        out.puts digest
        0
      rescue Error => e
        err.puts "registry download failed: #{e.message}"
        1
      end

      def initialize(name, http:, sleeper:, clock:)
        @name = name
        @http = http
        @sleeper = sleeper
        @clock = clock
      end

      # The publish job's decision: may we push? Returns :push (version absent)
      # or :skip (already published with exactly our bytes). Anything else
      # fails closed.
      #
      # A 404 means only that this version is absent — it says nothing about
      # whether the gem name is claimed.
      def check(version, sha256)
        sha256 = normalize_sha(sha256)
        response = get_with_retries(version_uri(version))

        case response.status
        when 404
          :push
        when 200
          published = published_sha(response.body, version)
          if published == sha256
            :skip
          else
            raise Error, "#{@name} #{version} is already published with sha256 #{published}; " \
                         "our artifact is #{sha256} — refusing to touch it"
          end
        else
          raise Error, "unexpected HTTP #{response.status} from #{version_uri(version)}"
        end
      end

      # The confirm job: wait (bounded) until the registry reports exactly our
      # version with exactly our digest, then download the canonical bytes and
      # verify those too. Returns the canonical bytes.
      def confirm(version, sha256, deadline: CONFIRM_DEADLINE)
        sha256 = normalize_sha(sha256)
        poll(version, sha256, deadline: deadline)

        bytes, digest = verified_download(version)
        unless digest == sha256
          raise Error, "canonical .gem digest #{digest} does not match our artifact digest #{sha256}"
        end
        bytes
      end

      # The recovery path: fetch the canonical bytes for a published version
      # and verify them against the digest the registry itself reports.
      # Returns [ bytes, digest ].
      def verified_download(version)
        response = get_with_retries(version_uri(version))
        unless response.status == 200
          raise Error, "expected #{@name} #{version} to be published; got HTTP #{response.status}"
        end

        published = published_sha(response.body, version)
        bytes = download(version)
        digest = Digest::SHA256.hexdigest(bytes)
        unless digest == published
          raise Error, "downloaded .gem digest #{digest} does not match registry-reported sha256 #{published}"
        end
        [ bytes, digest ]
      end

      private
        def version_uri(version)
          URI("#{HOST}/api/v2/rubygems/#{@name}/versions/#{version}.json")
        end

        def normalize_sha(sha256)
          sha = sha256.to_s.downcase
          raise Error, "not a sha256 hex digest: #{sha256.inspect}" unless sha.match?(/\A\h{64}\z/)
          sha
        end

        # Parse the v2 version payload, failing closed on anything unexpected.
        def published_sha(body, version)
          data = JSON.parse(body)
          raise Error, "unexpected response shape: #{data.class}" unless data.is_a?(Hash)
          unless data["number"] == version
            raise Error, "response is for version #{data['number'].inspect}, expected #{version.inspect}"
          end
          sha = data["sha"]
          unless sha.is_a?(String) && sha.match?(/\A\h{64}\z/)
            raise Error, "response has no usable sha256 (got #{sha.inspect})"
          end
          sha.downcase
        rescue JSON::ParserError => e
          raise Error, "malformed JSON from registry: #{e.message}"
        end

        # One GET; network-level faults become RetryableFault.
        def get_once(uri)
          @http.call(uri)
        rescue Timeout::Error, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError,
               SocketError, SystemCallError, EOFError, IOError => e
          raise RetryableFault, "#{e.class}: #{e.message}"
        end

        # GET with bounded backoff on 429/5xx/network faults. Returns the
        # response for every other status; callers own the status decision.
        def get_with_retries(uri)
          attempts = 0
          begin
            attempts += 1
            response = get_once(uri)
            raise RetryableFault, "HTTP #{response.status}" if retryable_status?(response.status)
            response
          rescue RetryableFault => e
            raise Error, "#{uri} unavailable after #{attempts} attempts (#{e.message})" if attempts >= MAX_ATTEMPTS
            @sleeper.call(BACKOFF_BASE * attempts)
            retry
          end
        end

        def retryable_status?(status)
          status == 429 || (500..599).cover?(status)
        end

        # Poll until the registry reports exactly (version, sha256): 404 keeps
        # polling, 429/5xx/network faults back off, malformed bodies retry a
        # bounded number of times, a different sha fails immediately, and the
        # deadline fails.
        def poll(version, sha256, deadline:)
          started = @clock.call
          faults = 0
          malformed = 0

          loop do
            if @clock.call - started >= deadline
              raise Error, "gave up waiting for #{@name} #{version} after #{deadline}s"
            end

            begin
              response = get_once(version_uri(version))
            rescue RetryableFault
              malformed = 0
              faults += 1
              @sleeper.call(BACKOFF_BASE * faults)
              next
            end

            case response.status
            when 200
              begin
                published = published_sha(response.body, version)
              rescue Error
                malformed += 1
                raise if malformed >= MALFORMED_LIMIT
                @sleeper.call(POLL_INTERVAL)
                next
              end

              return if published == sha256
              raise Error, "registry reports #{@name} #{version} with sha256 #{published}; " \
                           "our artifact is #{sha256} — stopping for a human"
            when 404
              malformed = 0
              @sleeper.call(POLL_INTERVAL)
            when 429, 500..599
              malformed = 0
              faults += 1
              @sleeper.call(BACKOFF_BASE * faults)
            else
              raise Error, "unexpected HTTP #{response.status} from #{version_uri(version)}"
            end
          end
        end

        # Fetch the canonical .gem bytes, following at most MAX_REDIRECTS
        # https-only redirects.
        def download(version)
          uri = URI("#{HOST}/gems/#{@name}-#{version}.gem")
          redirects = 0

          loop do
            response = get_with_retries(uri)

            case response.status
            when 200
              return response.body
            when 301, 302, 303, 307, 308
              redirects += 1
              raise Error, "too many redirects downloading #{@name}-#{version}.gem" if redirects > MAX_REDIRECTS
              location = response.location
              raise Error, "redirect without a Location header" if location.nil? || location.empty?
              # Location may legitimately be relative or scheme-relative:
              # resolve it against the current URI, then enforce https-only.
              begin
                target = URI.join(uri.to_s, location)
              rescue URI::Error => e
                raise Error, "unusable redirect location #{location.inspect}: #{e.message}"
              end
              raise Error, "refusing non-https redirect to #{target}" unless target.is_a?(URI::HTTPS)
              uri = target
            else
              raise Error, "unexpected HTTP #{response.status} downloading #{uri}"
            end
          end
        end
    end
  end
end
