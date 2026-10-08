json.partial! "upright/public/api/page"
json.scheduled_maintenances @maintenances, partial: "upright/public/api/incidents/incident", as: :incident
