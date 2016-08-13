class PaletteExtractionJob < ApplicationJob
  queue_as :default

  def perform(photo)
    url = Ix.path(photo.original_path).to_url(palette: 'json')
    json = JSON.parse(HTTParty.get(url).body)
    dominant_colors = json['dominant_colors']
    hex_colors = dominant_colors.each do |k, v|
      dominant_colors[k] = dominant_colors[k]['hex']
    end
    photo.color_palette_json = hex_colors.to_json
    photo.save
  end
end
