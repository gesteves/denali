class FlickrJob < ApplicationJob
  queue_as :default

  def perform(entry)
    return if !entry.is_published? || !entry.is_photo? || !Rails.env.production?
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

    entry.photos.each do |p|
      response = flickr.upload_photo open(p.original_url).path, title: title, description: body, tags: all_tags
      logger.tagged('Social', 'Flickr') { logger.info { "Photo #{response} created" } }
    end
  end
end
