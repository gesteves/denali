class PhotoPaletteWorker < ApplicationWorker

  def perform(photo_id)
    photo = Photo.find(photo_id)
    palette = request_palette(photo)
    photo.color_palette = palette['colors'].map { |c| c['hex'] }.join(',')
    photo.save
  end

  private
  def request_palette(photo)
    request = HTTParty.get(photo.palette_url)
    JSON.parse(request.body)
  end
end
