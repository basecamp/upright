# Two entry points share this map. The admin app loads "application"; the public
# status page loads "upright/public". Pins used only by the admin app are
# preloaded for the "application" entry point alone, so the public page does not
# fetch Turbo, Stimulus, Leaflet or the charts library.

# Admin app
pin "application", to: "upright/application.js", preload: "application"
pin "upright/application", to: "upright/application.js", preload: "application"
pin "upright/controllers/application", to: "upright/controllers/application.js", preload: "application"
pin "upright/controllers", to: "upright/controllers/index.js", preload: "application"

pin_all_from Upright::Engine.root.join("app/javascript/upright/controllers"),
             under: "upright/controllers",
             to: "upright/controllers",
             preload: "application"

pin "@hotwired/turbo-rails", to: "https://cdn.jsdelivr.net/npm/@hotwired/turbo-rails@8.0.20/+esm", preload: "application"
pin "@hotwired/turbo", to: "https://cdn.jsdelivr.net/npm/@hotwired/turbo@8.0.20/+esm", preload: "application"
pin "@hotwired/stimulus", to: "https://cdn.jsdelivr.net/npm/@hotwired/stimulus@3.2.2/dist/stimulus.js", preload: "application"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: "application"
pin "@rails/actioncable/src", to: "https://cdn.jsdelivr.net/npm/@rails/actioncable@8.1.100/src/index.js", preload: "application"
pin "leaflet", to: "https://cdn.jsdelivr.net/npm/leaflet@1.9.4/dist/leaflet-src.esm.js", preload: "application"
pin "frappe-charts", to: "https://cdn.jsdelivr.net/npm/frappe-charts@1.6.2/dist/frappe-charts.min.esm.js", preload: "application"

# Public status page
pin "upright/public", to: "upright/public.js", preload: "upright/public"

# Shared
pin "local-time", to: "local-time.es2017-esm.js", preload: true
