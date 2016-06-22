json.cache! "maps/photos/#{@photoblog.id}/#{@photoblog.updated_at.to_i}" do
  json.array! @photoblog.entries.photo_entries.published.mapped.joins(:photos).includes(:photos).where('photos.latitude is not null AND photos.longitude is not null') do |e|
    e.photos.each do |p|
      json.type 'Feature'
      json.geometry do
        json.type 'Point'
        json.coordinates [p.longitude, p.latitude]
      end
      json.properties do
        json.title e.title
        json.description tooltip_content(p, e)
      end
    end
  end
end
