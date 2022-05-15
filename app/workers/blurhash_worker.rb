class BlurhashWorker < ApplicationWorker

  def perform(photo_id)
    photo = Photo.find(photo_id)
    raise UnprocessedPhotoError unless photo.has_dimensions?

    if blurhash = Blurhash.encode(photo.blurhash_url).presence
      photo.blurhash = blurhash
      photo.save
    end
  end
end
