module Upright
  class Site
    attr_reader :code, :city, :country, :geohash, :stagger_index

    def initialize(code:, city: nil, country: nil, geohash: nil, provider: nil, stores_metrics: false, primary: false, stagger_index: 0)
      @code = code.to_sym
      @city = city
      @country = country
      @geohash = geohash
      @provider = provider
      @stores_metrics = stores_metrics
      @primary = primary
      @stagger_index = stagger_index
    end

    def stores_metrics?
      @stores_metrics
    end

    def primary?
      @primary
    end

    def host
      URI.parse(url).host
    end

    def provider
      @provider.to_s.inquiry
    end

    def default_timeout
      Upright.configuration.default_timeout
    end

    def latitude
      coordinates.first
    end

    def longitude
      coordinates.last
    end

    def url
      Upright::Engine.routes.url_helpers.root_url(subdomain: code)
    end

    def to_leaflet
      { hostname: host, city: city, lat: latitude, lon: longitude, url: url }
    end

    private
      def coordinates
        @coordinates ||= Upright::Geohash.decode(geohash).first
      end
  end
end
