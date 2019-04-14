class FlickrGroupWorker < ApplicationWorker
  sidekiq_options queue: 'low'

  def perform(photo_id, group_id)
    return if !Rails.env.production?
    FlickRaw.api_key = ENV['flickr_consumer_key']
    FlickRaw.shared_secret = ENV['flickr_consumer_secret']

    flickr = FlickRaw::Flickr.new
    flickr.access_token = ENV['flickr_access_token']
    flickr.access_secret = ENV['flickr_access_token_secret']

    begin
      flickr.groups.pools.add(photo_id: photo_id, group_id: group_id)
    rescue FlickRaw::FailedResponse
    end
  end
end
