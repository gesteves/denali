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
    width = config.photo_sizes[:large].w
    opts = set_coordinates(entry.photos.first)
    twitter.update_with_media(tweet, File.new(open(entry.photos.first.url(width)).path), opts) if Rails.env.production?
  end

  def build_tweet(entry, config)
    url_length = config.short_url_length_https
    media_length = config.characters_reserved_per_media
    max_length = 138 - url_length - media_length
    coder = HTMLEntities.new
    text = coder.decode(entry.tweet_text.blank? ? entry.plain_title : entry.tweet_text)
    "#{truncate(text, length: max_length, omission: '…')} #{permalink_url(entry)}"
  end

  def set_coordinates(photo)
    opts = {}
    if photo.latitude.present? && photo.longitude.present?
      opts[:lat] = photo.latitude
      opts[:long] = photo.longitude
      opts[:display_coordinates] = true
    end
    opts
  end
end
