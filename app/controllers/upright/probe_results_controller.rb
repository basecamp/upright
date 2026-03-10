class Upright::ProbeResultsController < Upright::ApplicationController
  def index
    set_page_and_extract_portion_from probe_results, ordered_by: { id: :desc }

    @probe_names = Upright::ProbeResult.by_type(params[:probe_type]).distinct.pluck(:probe_name).sort
    @chart_data = @page.records.map(&:to_chart)
  end

  private
    def probe_results
      Upright::ProbeResult
        .by_type(params[:probe_type])
        .by_status(params[:status])
        .by_name(params[:probe_name])
        .by_date(params[:date])
        .with_attached_artifacts
    end
end
