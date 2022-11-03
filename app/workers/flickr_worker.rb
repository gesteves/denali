class FlickrWorker < ApplicationWorker
  sidekiq_options queue: 'high'

  def perform(photo_id)
    return if !Rails.env.production?
    return if ENV['FLICKR_CONSUMER_KEY'].blank? || ENV['FLICKR_CONSUMER_SECRET'].blank? || ENV['FLICKR_ACCESS_TOKEN'].blank? || ENV['FLICKR_ACCESS_TOKEN_SECRET'].blank?

    photo = Photo.find(photo_id)
    raise UnprocessedPhotoError unless photo.has_dimensions?

    entry = photo.entry
    blog = entry.blog

    return if blog.flickr.blank?

    flickr = FlickRaw::Flickr.new ENV['FLICKR_CONSUMER_KEY'], ENV['FLICKR_CONSUMER_SECRET']
    flickr.access_token = ENV['FLICKR_ACCESS_TOKEN']
    flickr.access_secret = ENV['FLICKR_ACCESS_TOKEN_SECRET']

    title = entry.plain_title
    caption = photo.flickr_caption

    tags = photo.flickr_tags
    photo_path = URI.open(photo.image.url).path
    photo_id = flickr.upload_photo photo_path, title: title, description: caption, tags: tags

    if photo_id&.match?(/\d+/)
      entry.flickr_groups.each do |group_url|
        FlickrGroupWorker.perform_async(photo_id, group_url)
      end
      entry.flickr_albums.each do |album_url|
        FlickrAlbumWorker.perform_async(photo_id, album_url)
      end
    end
  end
end
