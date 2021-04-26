class TwitterWorker < ApplicationWorker
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
    max_length = 250

    caption = entry.tweet_text.present? ? entry.tweet_text : entry.plain_title
    tweet = "#{truncate(caption.gsub(/\s+&\s+/, ' and '), length: max_length, omission: '…')} #{entry.permalink_url}"

    opts = set_coordinates(entry)
    twitter.update(tweet, opts)
  end

  def set_coordinates(entry)
    opts = {}
    photo = entry.photos.first
    if entry.show_in_map? && photo.latitude.present? && photo.longitude.present?
      opts[:lat] = photo.latitude
      opts[:long] = photo.longitude
      opts[:display_coordinates] = false
    end
    opts
  end
end
