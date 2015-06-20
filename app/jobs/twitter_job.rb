require 'open-uri'
class TwitterJob < ActiveJob::Base
  include ActionView::Helpers::TextHelper
  include Addressable

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
      twitter.update_with_media(tweet, get_photo(entry, config))
    else
      twitter.update(tweet)
    end
  end

  def build_tweet(entry, config)
    max_length = max_length(entry, config)
    "#{truncate(entry.formatted_title, length: max_length, omission: '…')} #{permalink_url(entry)}"
  end

  def max_length(entry, config)
    entry.is_text? ? 135 - config.short_url_length_https : 135 - config.short_url_length_https - config.characters_reserved_per_media
  end

  def get_photo(entry, config)
    width = config.photo_sizes[:large].width || 2048
    open(entry.photos.first.url(width))
  end
end
