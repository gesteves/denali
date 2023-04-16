require 'mini_magick'
class BlurhashWorker < ApplicationWorker

  def perform(photo_id)
    photo = Photo.find(photo_id)
    raise UnprocessedPhotoError unless photo.has_dimensions?

    image = MiniMagick::Image.open(photo.url(width: 1200))

    if blurhash = Blurhash.encode(image.width, image.height, image.get_pixels.flatten).presence
      photo.blurhash = blurhash
      photo.save
    end
  end
end
