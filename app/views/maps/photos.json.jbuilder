json.array! @entries do |e|
  e.photos.each do |p|
    json.type "Feature"
    json.geometry do
      json.type "Point"
      json.coordinates [p.longitude, p.latitude]
    end
    json.properties do
      json.title e.title
      json.set! 'marker-color', '#bf0222'
      json.set! 'marker-size', 'small'
    end
  end
end
