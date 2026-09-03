class Upright::Probes::Status::Probe
  include Comparable

  attr_reader :name, :type, :probe_target, :site_statuses

  def initialize(name:, type:, probe_target:, site_statuses:)
    @name = name
    @type = type
    @probe_target = probe_target
    @site_statuses = site_statuses
  end

  def self.key_for(name:, type:, probe_target:, **)
    [ name, type, probe_target ]
  end

  def key
    self.class.key_for(name:, type:, probe_target:)
  end

  def status_for_site(code)
    site_statuses.find { |s| s.site_code == code.to_s }
  end

  def any_down?
    site_statuses.any?(&:down?)
  end

  def <=>(other)
    [ any_down? ? 0 : 1, type, name ] <=> [ other.any_down? ? 0 : 1, other.type, other.name ]
  end
end
