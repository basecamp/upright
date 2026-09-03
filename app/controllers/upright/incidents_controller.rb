class Upright::IncidentsController < Upright::ApplicationController
  before_action :set_incident, only: %i[ edit update destroy ]

  def index
    @current  = Upright::Incident.active.order(starts_at: :desc)
    @upcoming = Upright::Maintenance.upcoming.order(:starts_at)
    @past     = Upright::Incident.past.limit(50)
  end

  def new
    @incident = incident_class.new(starts_at: Time.current)
  end

  def create
    @incident = incident_class.new(incident_params)

    if @incident.save
      redirect_to incidents_path, notice: "#{@incident.model_name.human} created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @incident.update(incident_params)
      redirect_to incidents_path, notice: "Saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @incident.destroy
    redirect_to incidents_path, notice: "Deleted."
  end

  private
    def set_incident
      @incident = Upright::Incident.find(params[:id])
    end

    def incident_class
      maintenance = ActiveModel::Type::Boolean.new.cast(params[:maintenance])
      maintenance ? Upright::Maintenance : Upright::Incident
    end

    def incident_params
      params.expect(incident: [ :title, :impact, :starts_at, :ends_at, :body, service_codes: [] ])
    end
end
