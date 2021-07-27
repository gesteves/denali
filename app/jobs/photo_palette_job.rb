class PhotoPaletteJob < ApplicationJob
  queue_as :default

  def perform(photo)
    return # make this job a noop since thumbor doesn't have a palette endpoint
    palette = request_palette(photo)
    photo.color_vibrant = palette.dig('dominant_colors', 'vibrant', 'hex')
    photo.color_muted   = palette.dig('dominant_colors', 'muted', 'hex')
    photo.color_palette = palette['colors'].map { |c| c['hex'] }.join(',')
    photo.save
  end

  private
  def request_palette(photo)
    request = HTTParty.get(photo.palette_url)
    JSON.parse(request.body)
  end
end
