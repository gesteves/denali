class FlickrWorker < ApplicationWorker
  sidekiq_options queue: 'high'

  def perform(photo_id)
    photo = Photo.find(photo_id)
    entry = photo.entry
    return if !entry.is_published? || !Rails.env.production?
    begin
      FlickRaw.api_key = ENV['flickr_consumer_key']
      FlickRaw.shared_secret = ENV['flickr_consumer_secret']

      flickr = FlickRaw::Flickr.new
      flickr.access_token = ENV['flickr_access_token']
      flickr.access_secret = ENV['flickr_access_token_secret']

      title = entry.title

      if entry.body.present?
        body = "#{entry.formatted_body}\n\n#{entry.permalink_url}"
      else
        body = entry.permalink_url
      end

      all_tags = entry.combined_tag_list.map { |t| "\"#{t.gsub(/["']/, '')}\"" }.join(' ')

      photo_id = flickr.upload_photo open(photo.image.service_url).path, title: title, description: body, tags: all_tags

      if photo_id.present?
        entry.flickr_groups.each do |group_url|
          FlickrGroupWorker.perform_async(photo_id, group_url)
        end
      end
    rescue FlickRaw::FailedResponse
    end
  end
end
