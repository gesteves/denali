json.cache! "maps/photos/#{@photoblog.id}/#{@photoblog.updated_at.to_i}" do
  json.array! @entries do |e|
    json.cache! "maps/photos/entry/#{e.id}/#{e.updated_at.to_i}" do
      e.photos.each do |p|
        json.type "Feature"
        json.geometry do
          json.type "Point"
          json.coordinates [p.longitude, p.latitude]
        end
        json.properties do
          json.title e.title
          json.description tooltip_content(p, e)
        end
      end
    end
  end
end
