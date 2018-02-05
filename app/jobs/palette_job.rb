class PaletteJob < ApplicationJob
  queue_as :default

  def perform(photo)
    palette = request_palette(photo)
    photo.color_vibrant       = palette.dig('dominant_colors', 'vibrant', 'hex')
    photo.color_vibrant_dark  = palette.dig('dominant_colors', 'vibrant_dark', 'hex')
    photo.color_vibrant_light = palette.dig('dominant_colors', 'vibrant_light', 'hex')
    photo.color_muted         = palette.dig('dominant_colors', 'muted', 'hex')
    photo.color_muted_light   = palette.dig('dominant_colors', 'muted_light', 'hex')
    photo.color_muted_dark    = palette.dig('dominant_colors', 'muted_dark', 'hex')
    photo.save
  end

  def request_palette(photo)
    request = HTTParty.get(photo.palette_url)
    JSON.parse(request.body)
  end
end
