class FlickrWorker < ApplicationWorker
  sidekiq_options queue: 'high'

  def perform(photo_id)
    return unless Rails.env.production?
    return if ENV['FLICKR_CONSUMER_KEY'].blank? || ENV['FLICKR_CONSUMER_SECRET'].blank?

    photo = Photo.find(photo_id)
    raise UnprocessedPhotoError unless photo.has_dimensions?

    flickr_account = photo.entry.user.flickr_account
    return if flickr_account.blank?

    flickr = FlickRaw::Flickr.new(ENV['FLICKR_CONSUMER_KEY'], ENV['FLICKR_CONSUMER_SECRET'])
    flickr.access_token = flickr_account.access_token
    flickr.access_secret = flickr_account.access_token_secret

    entry = photo.entry
    title = entry.plain_title
    caption = photo.flickr_caption

    tags = photo.flickr_tags
    photo_path = URI.open(photo.image.url).path
    uploaded_photo_id = flickr.upload_photo photo_path, title: title, description: caption, tags: tags

    if uploaded_photo_id&.match?(/\d+/)
      entry.flickr_groups.each do |group_url|
        FlickrGroupWorker.perform_async(uploaded_photo_id, group_url, entry.user_id)
      end
      entry.flickr_albums.each do |album_url|
        FlickrAlbumWorker.perform_async(uploaded_photo_id, album_url, entry.user_id)
      end
    end
  end
end
