class Upright::Incidents::UpdatesController < Upright::ApplicationController
  def create
    @incident = Upright::Incident.find(params[:incident_id])
    update = @incident.record_update(incident_update_params)
    redirect_to edit_incident_path(@incident),
      flash: update.persisted? ? { notice: "Update posted." } : { alert: "Couldn't post update — check the status and message." }
  end

  private
    def incident_update_params
      params.expect(incident_update: [ :status, :body ])
    end
end
