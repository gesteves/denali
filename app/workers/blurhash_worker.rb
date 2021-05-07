class BlurhashWorker < ApplicationWorker

  def perform(photo_id)
    photo = Photo.find(photo_id)
    raise UnprocessedPhotoError unless photo.processed?

    blurhash = blurhash(photo)
    if blurhash&.size > 6 && blurhash&.size < 100
      photo.blurhash = blurhash
      photo.save
    end
  end

  private
  def blurhash(photo)
    HTTParty.get(photo.blurhash_url).body
  end
end
