class FlickrSetMetaWorker < ApplicationWorker
  sidekiq_options queue: 'low'

  def perform(photo_id, flickr_id)
    return if !Rails.env.production?
    return if ENV['flickr_consumer_key'].blank? || ENV['flickr_consumer_secret'].blank? || ENV['flickr_access_token'].blank? || ENV['flickr_access_token_secret'].blank?

    flickr = FlickRaw::Flickr.new ENV['flickr_consumer_key'], ENV['flickr_consumer_secret']
    flickr.access_token = ENV['flickr_access_token']
    flickr.access_secret = ENV['flickr_access_token_secret']

    photo = Photo.find(photo_id)
    entry = photo.entry
    title = entry.plain_title
    description = photo.flickr_caption

    flickr.photos.setMeta(photo_id: flickr_id, title: title, description: description)
  end
end
