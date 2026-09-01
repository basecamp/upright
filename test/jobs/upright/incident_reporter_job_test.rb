require "test_helper"

class Upright::IncidentReporterJobTest < ActiveJob::TestCase
  test "reports downtime" do
    Upright::Incident.expects(:report_downtime)

    Upright::IncidentReporterJob.perform_now
  end
end
