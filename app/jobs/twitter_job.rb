class TwitterJob < ApplicationJob
  queue_as :default

  def perform(entry)
    twitter = Twitter::REST::Client.new do |config|
      config.consumer_key        = ENV['twitter_consumer_key']
      config.consumer_secret     = ENV['twitter_consumer_secret']
      config.access_token        = ENV['twitter_access_token']
      config.access_token_secret = ENV['twitter_access_token_secret']
    end
    config = twitter.configuration
    tweet = build_tweet(entry, config)
    if entry.is_photo?
      width = config.photo_sizes[:large].w
      twitter.update_with_media(tweet, File.new(open(entry.photos.first.url(width)).path)) if Rails.env.production?
    else
      twitter.update(tweet) if Rails.env.production?
    end
  end

  def build_tweet(entry, config)
    url_length = config.short_url_length_https
    media_length = config.characters_reserved_per_media
    if entry.is_photo?
      max_length = 138 - url_length - media_length
    else
      max_length = 139 - url_length
    end
    text = entry.tweet_text.blank? ? entry.title : entry.tweet_text
    "#{truncate(text, length: max_length, omission: '…')} #{permalink_url(entry)}"
  end
end
