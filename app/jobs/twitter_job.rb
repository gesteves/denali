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
    if entry.is_photo?
      tweet = "#{truncate(entry.formatted_title, length: (140 - 48), omission: '…')} #{permalink_url(entry)}"
      twitter.update_with_media(tweet, open(entry.photos.first.url(2560)))
    else
      tweet = "#{truncate(entry.formatted_title, length: (140 - 25), omission: '…')} #{permalink_url(entry)}"
      twitter.update(tweet)
    end
  end
end
