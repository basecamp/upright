class PingProbe < FrozenRecord::Base
  include Upright::Probeable
  include Upright::ProbeYamlSource

  stagger_by_site 3.seconds

  def check
    @ping_output, status = Open3.capture2e("ping", "-c", "1", "-W", "5", host)
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
