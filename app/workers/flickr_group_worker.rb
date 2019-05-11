class FlickrGroupWorker < ApplicationWorker
  sidekiq_options queue: 'low'

  def perform(photo_id, group_url)
    return if !Rails.env.production?
    begin
      FlickRaw.api_key = ENV['flickr_consumer_key']
      FlickRaw.shared_secret = ENV['flickr_consumer_secret']

      flickr = FlickRaw::Flickr.new
      flickr.access_token = ENV['flickr_access_token']
      flickr.access_secret = ENV['flickr_access_token_secret']
      slug = group_url.split('/').last
      group = if /\d+@N\d+/.match? slug
        flickr.groups.getInfo(group_id: slug)
      else
        flickr.groups.getInfo(group_path_alias: slug)
      end
      flickr.groups.pools.add(photo_id: photo_id, group_id: group['nsid'])
    rescue FlickRaw::FailedResponse => e
      logger.error "[Flickr] #{group_url} #{e}"
    end
  end
end
