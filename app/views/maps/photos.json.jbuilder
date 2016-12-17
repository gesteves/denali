json.cache! "maps/photos/#{@photoblog.id}/#{@photoblog.updated_at.to_i}" do
  json.array! @photoblog.entries.mapped.pluck('photos.id', 'photos.longitude', 'photos.latitude') do |e|
    json.type 'Feature'
    json.geometry do
      json.type 'Point'
      json.coordinates [e[1], e[2]]
    end
    json.properties do
      json.id e[0]
    end
  end
end
