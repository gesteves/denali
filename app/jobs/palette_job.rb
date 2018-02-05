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
    photo.color               = is_color?(json.dig('colors'))
    photo.save
  end

  private
  def request_palette(photo)
    request = HTTParty.get(Ix.path(photo.original_path).to_url(palette: 'json', colors: 6))
    raise request.code if request.code != 200
    JSON.parse(request.body)
  end

  def is_color?(colors, opts = {})
    return false if colors.blank?
    !colors.reject { |c| c['red'] == c['green'] && c['red'] == c['blue'] }.empty?
  end
end
