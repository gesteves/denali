class FlickrAlbumWorker < ApplicationWorker
  sidekiq_options queue: 'low'

  def perform(photo_id, album_url)
    return if !Rails.env.production?
    begin
      flickr = FlickRaw::Flickr.new ENV['flickr_consumer_key'], ENV['flickr_consumer_secret']
      flickr.access_token = ENV['flickr_access_token']
      flickr.access_secret = ENV['flickr_access_token_secret']
      album_id = album_url.split('/').last

      flickr.photosets.addPhoto(photo_id: photo_id, photoset_id: album_id)
      flickr.photosets.reorderPhotos(photo_ids: photo_id, photoset_id: album_id)
    rescue FlickRaw::FailedResponse => e
      logger.error "[Flickr] Photo #{photo_id} failed to add to album #{album_url}: #{e}"
    end
  end
end
