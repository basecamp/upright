import { Controller } from "@hotwired/stimulus"
import * as L from "leaflet"

export default class extends Controller {
  static values = { sites: Array }

  connect() {
    const map = L.map(this.element, { scrollWheelZoom: false }).setView([30, 0], 2)

    L.tileLayer(this.tileUrl, { attribution: this.attribution }).addTo(map)

    for (const site of this.sitesValue) {
      if (!site.lat || !site.lon) continue

      L.marker([site.lat, site.lon])
        .addTo(map)
        .bindPopup(this.popupContent(site))
        .on("mouseover", function() { this.openPopup() })
        .on("mouseout", function() { this.closePopup() })
        .on("click", () => window.location.href = site.url)
    }
  }

  // Build the popup as DOM nodes so hostname and city render as text,
  // never as HTML.
  popupContent(site) {
    const content = document.createElement("div")
    const hostname = document.createElement("strong")
    hostname.textContent = site.hostname
    content.append(hostname, document.createElement("br"), site.city ?? "")
    return content
  }

  get tileUrl() {
    return "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
  }

  get attribution() {
    return '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
  }
}
