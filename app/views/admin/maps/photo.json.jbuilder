json.cache! @photo do
  json.html render(partial: 'photo', formats: :html, locals: { entry: @photo.entry, photo: @photo })
end
