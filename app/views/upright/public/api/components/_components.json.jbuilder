json.components services.each_with_index.to_a do |(service, index)|
  json.partial! "upright/public/api/components/component", service: service, position: index + 1
end
