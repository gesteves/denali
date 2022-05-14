class FlickrAlbumWorker < ApplicationWorker
  sidekiq_options queue: 'low'

  def perform(photo_id, album_url)
    return if !Rails.env.production?
    begin
      flickr = FlickRaw::Flickr.new ENV['FLICKR_CONSUMER_KEY'], ENV['FLICKR_CONSUMER_SECRET']
      flickr.access_token = ENV['FLICKR_ACCESS_TOKEN']
      flickr.access_secret = ENV['FLICKR_ACCESS_TOKEN_SECRET']
      album_id = album_url.split('/').last

      flickr.photosets.addPhoto(photo_id: photo_id, photoset_id: album_id)
      flickr.photosets.reorderPhotos(photo_ids: photo_id, photoset_id: album_id)
    rescue FlickRaw::FailedResponse => e
      logger.error "[Flickr] Photo #{photo_id} failed to add to album #{album_url}: #{e}"
    end
  end
end
