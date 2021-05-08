class BlurhashWorker < ApplicationWorker

  def perform(photo_id)
    photo = Photo.find(photo_id)
    raise UnprocessedPhotoError unless photo.processed?

    blurhash = blurhash(photo)
    photo.blurhash = blurhash
    photo.save if photo.has_valid_blurhash?
  end

  private
  def blurhash(photo)
    HTTParty.get(photo.blurhash_url).body
  end
end
