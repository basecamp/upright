xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.rss(version: "2.0") do
  xml.channel do
    xml.title "Upright Status"
    xml.link request.base_url
    xml.description "Currently degraded services"
    xml.lastBuildDate Time.current.rfc822

    @services.degraded.each do |issue|
      xml.item do
        xml.title "#{issue[:service].name} — #{status_label(issue[:status])}"
        xml.description "#{issue[:service].name} is currently #{status_label(issue[:status]).downcase} #{outage_duration_phrase(started_at: issue[:started_at])}."
        xml.pubDate issue[:started_at].rfc822 if issue[:started_at]
        xml.guid feed_item_guid(issue), isPermaLink: "false"
      end
    end
  end
end
