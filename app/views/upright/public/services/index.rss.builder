xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.rss(version: "2.0") do
  xml.channel do
    xml.title "Upright Status"
    xml.link upright.public_services_root_url
    xml.description "Currently degraded services"
    xml.lastBuildDate Time.current.rfc822

    @services.degraded.each do |issue|
      started_at = issue[:started_at] || Time.current
      xml.item do
        xml.title "#{issue[:service].name} — #{status_label(issue[:status])}"
        xml.description "#{issue[:service].name} is currently #{status_label(issue[:status]).downcase} #{outage_duration_phrase(started_at: issue[:started_at])}."
        xml.pubDate started_at.rfc822
        xml.guid "#{issue[:service].code}-#{started_at.to_i}", isPermaLink: "false"
      end
    end
  end
end
