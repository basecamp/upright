class Upright::Incidents::UpdatesController < Upright::ApplicationController
  before_action :set_incident
  before_action :set_update, only: %i[ edit update ]

  def create
    update = @incident.record_update(incident_update_params)
    redirect_to edit_incident_path(@incident),
      flash: update.persisted? ? { notice: "Update posted." } : { alert: "Couldn't post update — check the status and message." }
  end

  def edit
  end

  def update
    @update.update!(params.expect(incident_update: [ :body ]))
    redirect_to edit_incident_path(@incident), notice: "Update edited."
  end

  private
    def set_incident
      @incident = Upright::Incident.find(params[:incident_id])
    end

    def set_update
      @update = @incident.updates.find(params[:id])
    end

    def incident_update_params
      params.expect(incident_update: [ :status, :body ])
    end
end
