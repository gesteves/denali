class FlickrWorker < ApplicationWorker
  sidekiq_options queue: 'high'

  def perform(photo_id)
    photo = Photo.find(photo_id)
    entry = photo.entry
    return if !Rails.env.production?
    return if ENV['flickr_consumer_key'].blank? || ENV['flickr_consumer_secret'].blank? || ENV['flickr_access_token'].blank? || ENV['flickr_access_token_secret'].blank?
    flickr = FlickRaw::Flickr.new ENV['flickr_consumer_key'], ENV['flickr_consumer_secret']
    flickr.access_token = ENV['flickr_access_token']
    flickr.access_secret = ENV['flickr_access_token_secret']

    title = entry.title

    if entry.body.present?
      body = "#{entry.formatted_body}\n\nOriginally published at #{entry.permalink_url}"
    else
      body = "Originally published at #{entry.permalink_url}"
    end

    all_tags = entry.combined_tag_list.map { |t| "\"#{t.gsub(/["']/, '')}\"" }.join(' ')
    photo_path = URI.open(photo.image.service_url).path
    photo_id = flickr.upload_photo photo_path, title: title, description: body, tags: all_tags

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
