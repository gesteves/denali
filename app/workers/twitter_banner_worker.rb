class TwitterBannerWorker < ApplicationWorker
  sidekiq_options queue: 'high'

  def perform(entry_id)
    return if !Rails.env.production?
    entry = Entry.published.find(entry_id)
    raise UnprocessedPhotoError if entry.is_photo? && !entry.photos_processed?

    twitter = Twitter::REST::Client.new do |config|
      config.consumer_key        = ENV['twitter_consumer_key']
      config.consumer_secret     = ENV['twitter_consumer_secret']
      config.access_token        = ENV['twitter_access_token']
      config.access_token_secret = ENV['twitter_access_token_secret']
    end

    twitter.update_profile_banner(Base64.encode64(open(entry.photos.first.twitter_banner_url).read))
  end

end
