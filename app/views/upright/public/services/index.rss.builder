xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.rss(version: "2.0") do
  xml.channel do
    xml.title "Upright Status"
    xml.link request.base_url
    xml.description "Currently degraded services"
    xml.lastBuildDate Time.current.rfc822

    @status_page.outages.each do |outage|
      xml.item do
        xml.title "#{outage.service.name} — #{status_label(outage.status)}"
        xml.description "#{outage.service.name} is currently #{status_label(outage.status).downcase} #{outage_duration_description(started_at: outage.started_at)}."
        xml.pubDate outage.started_at.rfc822 if outage.started_at
        xml.guid feed_item_guid(outage), isPermaLink: "false"
      end
    end

    @status_page.active_events.each do |event|
      update = event.updates.first
      xml.item do
        xml.title "#{event.title} — #{status_label(event.status)}"
        xml.description update&.body.to_s
        xml.link public_incident_url(event)
        xml.pubDate (update&.created_at || event.starts_at).rfc822
        xml.guid "incident-#{event.id}-#{update&.id}", isPermaLink: "false"
      end
    end
  end
end
