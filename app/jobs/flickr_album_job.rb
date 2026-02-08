class FlickrAlbumJob < ApplicationJob
  sidekiq_options queue: 'low'

  def perform(photo_id, album_url, user_id = nil)
    return unless Rails.env.production?
    return if ENV['FLICKR_CONSUMER_KEY'].blank? || ENV['FLICKR_CONSUMER_SECRET'].blank?

    flickr_account = user_id.present? ? User.find(user_id).flickr_account : nil
    return if flickr_account.blank?

    begin
      flickr = FlickRaw::Flickr.new(ENV['FLICKR_CONSUMER_KEY'], ENV['FLICKR_CONSUMER_SECRET'])
      flickr.access_token = flickr_account.access_token
      flickr.access_secret = flickr_account.access_token_secret
      album_id = album_url.split('/').last

      flickr.photosets.addPhoto(photo_id: photo_id, photoset_id: album_id)
      flickr.photosets.reorderPhotos(photo_ids: photo_id, photoset_id: album_id)
    rescue FlickRaw::FailedResponse => e
      logger.error "[Flickr] Photo #{photo_id} failed to add to album #{album_url}: #{e}"
    end
  end
end
