json.cache! "maps/photo/#{@photo.cache_key}/" do
  json.html render(partial: 'photo.html.erb', locals: { entry: @photo.entry, photo: @photo })
end
