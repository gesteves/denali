class FlickrGroupJob < ApplicationJob
  sidekiq_options queue: 'low'

  def perform(photo_id, group_url, user_id = nil)
    return unless Rails.env.production?
    return if ENV['FLICKR_CONSUMER_KEY'].blank? || ENV['FLICKR_CONSUMER_SECRET'].blank?

    flickr_account = user_id.present? ? User.find(user_id).flickr_account : nil
    return if flickr_account.blank?

    begin
      flickr = FlickRaw::Flickr.new(ENV['FLICKR_CONSUMER_KEY'], ENV['FLICKR_CONSUMER_SECRET'])
      flickr.access_token = flickr_account.access_token
      flickr.access_secret = flickr_account.access_token_secret
      slug = group_url.split('/').last
      group = if /\d+@N\d+/.match? slug
        flickr.groups.getInfo(group_id: slug)
      else
        flickr.groups.getInfo(group_path_alias: slug)
      end
      flickr.groups.pools.add(photo_id: photo_id, group_id: group['nsid'])
    rescue FlickRaw::FailedResponse => e
      logger.error "[Flickr] Photo #{photo_id} failed to add to group #{group_url}: #{e}"
    end
  end
end
