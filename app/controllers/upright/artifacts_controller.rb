class Upright::ArtifactsController < Upright::ApplicationController
  def show
    @artifact = ActiveStorage::Attachment.where(record_type: "Upright::ProbeResult").find(params[:id])
  end
end
