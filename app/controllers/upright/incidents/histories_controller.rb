class Upright::Incidents::HistoriesController < Upright::ApplicationController
  def show
    incidents = Upright::Incident.of_kind(params[:kind]).affecting(params[:service]).mentioning(params[:q]).preload(:affected_services)
    set_page_and_extract_portion_from incidents, ordered_by: { starts_at: :desc, id: :desc }, per_page: 25
  end
end
