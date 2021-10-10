class ImgixPurgeWorker < ApplicationWorker

  def perform(photo_id)
    photo = Photo.find(photo_id)
    photo.purge
  end
end
