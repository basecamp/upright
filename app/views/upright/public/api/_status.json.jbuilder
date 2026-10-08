json.status do
  json.indicator status_indicator(status_page.overall_status)
  json.description overall_status_label(status_page.overall_status)
end
