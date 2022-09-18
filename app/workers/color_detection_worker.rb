class ColorDetectionWorker < ApplicationWorker
  # TODO: Replace imgix with something else, e.g. minimagick
  def perform(photo_id)
    photo = Photo.find(photo_id)
    raise UnprocessedPhotoError unless photo.has_dimensions?
    colors = palette(photo)
    photo.dominant_color = dominant_color(colors)
    photo.black_and_white = is_black_and_white?(colors)
    photo.color = !is_black_and_white?(colors)
    photo.save
  end

  private

  def palette(photo)
    request = HTTParty.get(photo.palette_url)
    JSON.parse(request.body)
  end

  def dominant_color(colors)
    colors['dominant_colors'].first.last['hex']
  end

  def is_black_and_white?(colors)
    colors['dominant_colors'].values.map { |c| c['hex'].gsub('#', '') }.reject { |c| c.scan(/../).uniq.size == 1 }.empty?
  end
end
