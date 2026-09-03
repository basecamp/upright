require "net/http"
require "json"
require "resolv"

class Upright::Traceroute::IpMetadataLookup
  # ip-api.com only offers TLS with a paid key (the free /batch endpoint
  # rejects HTTPS outright). With IP_API_KEY set, lookups use the TLS pro
  # endpoint. Without a key they fall back to plain HTTP, which exposes the
  # looked-up hop IPs to on-path observers — the response is public geo
  # metadata, but consider a paid key or a local GeoIP database (e.g. maxmind's
  # GeoLite2 via the maxmind-geoip2 gem) if that leak matters to you.
  API_URL = "http://ip-api.com/batch"
  TLS_API_URL = "https://pro.ip-api.com/batch"
  TIMEOUT = 5.seconds
  GEOHASH_PRECISION = 6
  CACHE_TTL = 24.hours

  class << self
    def for_many(ips)
      results, uncached_ips = partition_cached(ips)

      if uncached_ips.any?
        fetch_batch(uncached_ips).each do |ip, metadata|
          cache_write(ip, metadata)
          results[ip] = metadata
        end
      end

      results
    end

    def clear_cache
      cache.clear
    end

    private
      def partition_cached(ips)
        results = {}
        uncached = []

        valid_ips(ips).each do |ip|
          cached = cache_read(ip)
          if cached
            results[ip] = cached
          else
            uncached << ip
          end
        end

        [ results, uncached ]
      end

      def valid_ips(ips)
        ips.compact.uniq.select { |ip| ip =~ Resolv::IPv4::Regex }
      end

      def fetch_batch(ips)
        uri = api_uri
        request = Net::HTTP::Post.new(uri)
        request.content_type = "application/json"
        request.body = ips.to_json

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", read_timeout: TIMEOUT, open_timeout: TIMEOUT) do |http|
          http.request(request)
        end

        if response.is_a?(Net::HTTPSuccess)
          parse_response(JSON.parse(response.body))
        else
          {}
        end
      end

      def api_uri
        if api_key.present?
          URI("#{TLS_API_URL}?key=#{api_key}")
        else
          URI(API_URL)
        end
      end

      def api_key
        ENV["IP_API_KEY"]
      end

      def parse_response(results)
        results.select { |result| result["status"] == "success" }.to_h do |result|
          [ result["query"], build_metadata(result) ]
        end
      end

      def build_metadata(result)
        {
          as: result["as"],
          isp: result["isp"],
          city: result["city"],
          country: result["country"],
          country_code: result["countryCode"],
          geohash: encode_geohash(result["lat"], result["lon"])
        }
      end

      def encode_geohash(latitude, longitude)
        if latitude && longitude
          Upright::Geohash.encode(latitude, longitude, GEOHASH_PRECISION)
        end
      end

      def cache_read(ip)
        cache.read("traceroute/ip_metadata/#{ip}")
      end

      def cache_write(ip, metadata)
        cache.write("traceroute/ip_metadata/#{ip}", metadata, expires_in: CACHE_TTL)
      end

      def cache
        @cache ||= if Rails.env.test?
          ActiveSupport::Cache::MemoryStore.new
        else
          ActiveSupport::Cache::FileStore.new(Rails.root.join("storage/ip_metadata"))
        end
      end
  end
end
