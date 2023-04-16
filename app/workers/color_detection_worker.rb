require 'mini_magick'
class ColorDetectionWorker < ApplicationWorker
  def perform(photo_id)
    photo = Photo.find(photo_id)
    raise UnprocessedPhotoError unless photo.has_dimensions?

    is_bw = is_black_and_white?(photo.url(width: 300))
    photo.black_and_white = is_bw
    photo.color = !is_bw
    photo.save
  end

  private

  def is_black_and_white?(image_url)
    image = MiniMagick::Image.open(image_url)
    histogram = image.run_command('convert', image.path, '-format', '%c', '-colors', '16', 'histogram:info:-')
    histogram.lines.each do |line|
      if line =~ /^\s*\d*:.*\s([a-fA-F0-9]{6})\s/
        color = $1
        red, green, blue = color[0..1].to_i(16), color[2..3].to_i(16), color[4..5].to_i(16)
        return false if red != green || green != blue
      end
    end
    true
  end
end
