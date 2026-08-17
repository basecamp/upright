class PingProbe < FrozenRecord::Base
  include Upright::Probeable
  include Upright::ProbeYamlSource

  stagger_by_site 3.seconds

  # Hostnames, IPv4, and IPv6 addresses only. The first character may not be
  # a dash, so a configured host can never be mistaken for a ping flag.
  HOST_PATTERN = /\A[a-z0-9:][a-z0-9:._-]*\z/i

  def check
    raise ArgumentError, "invalid ping host: #{host.inspect}" unless HOST_PATTERN.match?(host.to_s)

    @ping_output, status = Open3.capture2e("ping", "-c", "1", "-W", "5", "--", host)
    status.success?
  end

  def on_check_recorded(probe_result)
    if @ping_output.present?
      Upright::Artifact.new(name: "ping.log", content: @ping_output).attach_to(probe_result)
    end
  end

  def probe_type = "ping"
  def probe_target = host
end
