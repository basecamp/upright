class Upright::Rollups::DailyUptime
  attr_reader :day

  def initialize(day, sites: Upright.sites.select(&:stores_metrics?))
    @day, @sites = day, sites
  end

  def covered
    probe_uptimes.select(&:covered?)
  end

  def gappy
    probe_uptimes.reject(&:covered?)
  end

  private
    def probe_uptimes
      @probe_uptimes ||= best_covered_per_probe(reported_uptimes)
    end

    def best_covered_per_probe(probe_uptimes)
      probe_uptimes.group_by(&:probe_key).values.map { |reported| reported.max_by(&:coverage_fraction) }
    end

    def reported_uptimes
      @sites.flat_map { |site| Upright::Rollups::SiteUptime.new(site, on: day).probe_uptimes }
    end
end
