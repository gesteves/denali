class PhotoAnalyzeJob < ApplicationJob

  def perform(photo_id)
    photo = Photo.find(photo_id)
    photo.image.analyze
  end
end
