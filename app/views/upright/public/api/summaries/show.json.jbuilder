json.partial! "upright/public/api/page"
json.partial! "upright/public/api/components/components", services: @status_page.services
json.incidents @incidents, partial: "upright/public/api/incidents/incident", as: :incident
json.scheduled_maintenances @maintenances, partial: "upright/public/api/incidents/incident", as: :incident
json.partial! "upright/public/api/status", status_page: @status_page
