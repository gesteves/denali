class FlickrJob < ApplicationJob
  queue_as :default

  def perform(entry)
    FlickRaw.api_key = ENV['flickr_consumer_key']
    FlickRaw.shared_secret = ENV['flickr_consumer_secret']

    flickr = FlickRaw::Flickr.new
    flickr.access_token = ENV['flickr_access_token']
    flickr.access_secret = ENV['flickr_access_token_secret']

    title = entry.title

    if entry.body.present?
      body = "#{entry.formatted_body}\n\n#{entry.permalink_url(utm_source: 'flickr.com', utm_medium: 'social')}"
    else
      body = entry.permalink_url(utm_source: 'flickr')
    end

    all_tags = entry.combined_tag_list.map { |t| "\"#{t.gsub(/["']/, '')}\"" }.join(' ')

    entry.photos.each do |p|
      flickr.upload_photo open(p.original_url).path, title: title, description: body, tags: all_tags
    end
  end
end
