require "open3"

class Upright::Traceroute::Result
  PROBE_COUNT = 10
  MAX_HOPS = 30

  # Hostnames, IPv4, and IPv6 addresses (including a link-local zone such as
  # fe80::1%eth0) only. The first character may not be a dash, so a configured
  # host can never be mistaken for an mtr flag.
  HOST_PATTERN = /\A[a-z0-9:][a-z0-9:._-]*(?:%[a-z0-9._-]+)?\z/i

  attr_reader :host, :hops, :raw_json

  def self.for(host)
    new(host).tap(&:run)
  end

  def initialize(host)
    raise ArgumentError, "invalid traceroute host: #{host.inspect}" unless HOST_PATTERN.match?(host.to_s)

    @host = host
    @hops = []
  end

  def run
    @raw_json = run_mtr
    @hops = build_hops(Upright::Traceroute::MtrParser.new(@raw_json).parse)
  end

  def reached_destination?
    hops.any? && hops.last.responded?
  end

  private
    def run_mtr
      stdout, _status = Open3.capture2(
        "mtr",
        "--json",
        "--aslookup",
        "--report-cycles", PROBE_COUNT.to_s,
        "--max-ttl", MAX_HOPS.to_s,
        "--", host.to_s
      )

      Rails.logger.info stdout

      stdout
    end

    def build_hops(parsed_hops)
      ips = parsed_hops.map { |h| h[:ip] }.compact
      metadata_by_ip = Upright::Traceroute::IpMetadataLookup.for_many(ips)

      parsed_hops.map.with_index do |hop_data, index|
        metadata = metadata_by_ip[hop_data[:ip]] || {}

        Upright::Traceroute::Hop.new(
          **hop_data,
          **metadata,
          geohash: index == 0 ? Upright.current_site.geohash : metadata[:geohash]
        )
      end
    end
end
