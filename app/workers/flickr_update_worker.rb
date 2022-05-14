class FlickrUpdateWorker < ApplicationWorker
  sidekiq_options queue: 'low'

  def perform(photo_id, flickr_id)
    return if !Rails.env.production?
    return if ENV['FLICKR_CONSUMER_KEY'].blank? || ENV['FLICKR_CONSUMER_SECRET'].blank? || ENV['FLICKR_ACCESS_TOKEN'].blank? || ENV['FLICKR_ACCESS_TOKEN_SECRET'].blank?

    flickr = FlickRaw::Flickr.new ENV['FLICKR_CONSUMER_KEY'], ENV['FLICKR_CONSUMER_SECRET']
    flickr.access_token = ENV['FLICKR_ACCESS_TOKEN']
    flickr.access_secret = ENV['FLICKR_ACCESS_TOKEN_SECRET']

    photo = Photo.find(photo_id)
    entry = photo.entry
    title = entry.plain_title
    description = photo.flickr_caption
    tags = photo.flickr_tags

    flickr.photos.setMeta(photo_id: flickr_id, title: title, description: description)
    flickr.photos.setTags(photo_id: flickr_id, tags: tags)
  end
end
