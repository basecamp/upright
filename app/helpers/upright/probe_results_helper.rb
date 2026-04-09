module Upright::ProbeResultsHelper
  def probe_type_icon(probe_type)
    registered = Upright.probe_types.find(probe_type)
    content_tag(:span, registered.icon, title: registered.name)
  end

  def type_filter_link(label, probe_type = nil)
    display_label = probe_type ? safe_join([ probe_type_icon(probe_type), " ", label ]) : label

    link_to display_label,
            site_root_path(probe_type: probe_type.presence, status: params[:status].presence),
            class: class_names(active: params[:probe_type].presence == probe_type)
  end

  def artifact_icon(artifact)
    case artifact.filename
    when Upright::ExceptionRecording::EXCEPTION_FILENAME then "💥"
    when /\.webm$/        then "🎬"
    when /^request\.log$/ then "📤"
    when /^response\./    then "📥"
    when /^smtp\.log$/    then "📧"
    else "📎"
    end
  end

  def results_summary(page)
    total = page.recordset.records_count
    current_count = page.records.size

    parts = if page.recordset.page_count > 1
      [ "Showing #{current_count} of #{total} results" ]
    else
      [ "Showing #{total} results" ]
    end

    parts << "for #{params[:probe_type].titleize} probes" if params[:probe_type].present?
    parts << "named #{params[:probe_name]}" if params[:probe_name].present?
    parts << "with status #{params[:status]}" if params[:status].present?
    parts << "on #{Date.parse(params[:date]).to_fs(:long)}" if params[:date].present?
    parts.join(" ")
  end
end
