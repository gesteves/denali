json.cache! "maps/photo/#{@photo.id}/#{@photo.updated_at.to_i}" do
  json.html tooltip_content(@photo, @photo.entry)
end
