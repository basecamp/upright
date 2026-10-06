require "test_helper"

class Upright::Incidents::UpdatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in
    on_subdomain :app
    @incident = upright_incidents(:reactive_resolved)
    @update = upright_incident_updates(:reactive_resolved_initial)
  end

  test "the timeline links each update to its edit form" do
    get upright.edit_incident_path(@incident)

    assert_select "turbo-frame##{dom_id(@update)} a[href=?]", upright.edit_incident_update_path(@incident, @update), text: "Edit"
  end

  test "edit shows the message in a form inside the update's frame" do
    get upright.edit_incident_update_path(@incident, @update)

    assert_response :success
    assert_select "turbo-frame##{dom_id(@update)} textarea[name=?]", "incident_update[body]", text: "We are investigating."
  end

  test "update changes the message and leaves the status" do
    patch upright.incident_update_path(@incident, @update), params: { incident_update: { body: "We are investigating slow page loads.", status: "resolved" } }

    assert_redirected_to upright.edit_incident_path(@incident)
    assert_equal "We are investigating slow page loads.", @update.reload.body
    assert_equal "investigating", @update.status
  end

  test "an update can only be edited through its own incident" do
    patch upright.incident_update_path(upright_incidents(:reactive_other), @update), params: { incident_update: { body: "Changed" } }

    assert_response :not_found
    assert_equal "We are investigating.", @update.reload.body
  end

  private
    def dom_id(record) = ActionView::RecordIdentifier.dom_id(record)
end
