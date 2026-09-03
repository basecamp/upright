require "test_helper"

class Upright::MaintenanceTest < ActiveSupport::TestCase
  setup { travel_to Time.utc(2026, 6, 15, 12) }

  test "is an Incident via STI and forces the maintenance impact" do
    maintenance = Upright::Maintenance.create!(title: "Upgrade", status: "scheduled", impact: "major",
      starts_at: 1.hour.from_now, ends_at: 2.hours.from_now)

    assert maintenance.maintenance?
    assert_kind_of Upright::Incident, maintenance
    assert_equal "maintenance", maintenance.impact
    assert_equal "Upright::Maintenance", maintenance.type
  end

  test "requires an end that is after the start" do
    maintenance = upright_incidents(:upcoming)
    maintenance.ends_at = maintenance.starts_at - 1.hour

    assert_not maintenance.valid?
    assert maintenance.errors[:ends_at].any?
  end

  test "rejects a reactive-incident status" do
    maintenance = upright_incidents(:upcoming)
    maintenance.status = "investigating"

    assert_not maintenance.valid?
  end

  test "auto_advance_status starts an in-window maintenance without completing it" do
    maintenance = upright_incidents(:started_scheduled)

    maintenance.auto_advance_status

    assert_equal "in_progress", maintenance.reload.status
    assert_nil maintenance.resolved_at
  end

  test "auto_advance_status catches up a fully-elapsed window through to completed" do
    maintenance = upright_incidents(:elapsed_scheduled)

    maintenance.auto_advance_status

    assert_equal "completed", maintenance.reload.status
    assert_not_nil maintenance.resolved_at
  end

  test "upcoming and active scopes" do
    assert_includes Upright::Maintenance.upcoming, upright_incidents(:upcoming)
    assert_not_includes Upright::Maintenance.upcoming, upright_incidents(:in_progress)
    assert_includes Upright::Maintenance.active, upright_incidents(:in_progress)
    assert_not_includes Upright::Maintenance.active, upright_incidents(:upcoming)
  end
end
