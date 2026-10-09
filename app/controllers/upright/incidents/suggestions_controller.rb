class Upright::Incidents::SuggestionsController < Upright::ApplicationController
  before_action :set_incident

  def index
    render json: suggestions.map(&:to_h)
  end

  private
    def set_incident
      @incident = if params[:incident_id]
        Upright::Incident.find(params[:incident_id])
      else
        Upright::Incident.class_for(maintenance: params[:maintenance]).new(service_codes: service_codes, impact: impact)
      end
    end

    def service_codes
      Array(params.dig(:incident, :service_codes))
    end

    def impact
      params.dig(:incident, :impact).presence_in(Upright::Incident::IMPACTS) || "minor"
    end

    def suggestions
      if params[:field] == "title"
        @incident.suggestions.titles
      else
        @incident.suggestions.messages(status: status)
      end
    end

    def status
      params.dig(:incident_update, :status).presence_in(@incident.class::STATUSES) || @incident.class::STATUSES.first
    end
end
