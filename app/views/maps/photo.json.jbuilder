json.cache! @photo do
  json.html render(partial: 'photo.html.erb', locals: { entry: @photo.entry, photo: @photo })
end
