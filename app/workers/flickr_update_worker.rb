class FlickrUpdateWorker < ApplicationWorker
  sidekiq_options queue: 'low'

  def perform(photo_id, flickr_id)
    return unless Rails.env.production?
    return if ENV['FLICKR_CONSUMER_KEY'].blank? || ENV['FLICKR_CONSUMER_SECRET'].blank?

    photo = Photo.find(photo_id)
    flickr_account = photo.entry.user.flickr_account
    return if flickr_account.blank?

    flickr = FlickRaw::Flickr.new(ENV['FLICKR_CONSUMER_KEY'], ENV['FLICKR_CONSUMER_SECRET'])
    flickr.access_token = flickr_account.access_token
    flickr.access_secret = flickr_account.access_token_secret

    entry = photo.entry
    title = entry.plain_title
    description = photo.flickr_caption
    tags = photo.flickr_tags

    flickr.photos.setMeta(photo_id: flickr_id, title: title, description: description)
    flickr.photos.setTags(photo_id: flickr_id, tags: tags)
  end
end
