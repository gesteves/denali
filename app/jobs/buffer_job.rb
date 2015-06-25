require 'httparty'
class BufferJob < ActiveJob::Base
  include Addressable

  queue_as :default

  def perform(entry)
    HTTParty.post('https://api.bufferapp.com/1/updates/create.json', body: build_body(entry)) if entry.is_photo?
  end

  def get_profile_ids
    response = JSON.parse(HTTParty.get("https://api.bufferapp.com/1/profiles.json?access_token=#{ENV['buffer_access_token']}").body)
    response.select{ |profile| profile['service'] == 'facebook' }.map{ |profile| profile['id'] }
  end

  def build_body(entry)
    {
      profile_ids: get_profile_ids,
      text: "#{entry.formatted_title}\n\n#{short_permalink_url(entry)}",
      shorten: false,
      media: build_media(entry),
      now: true,
      access_token: ENV['buffer_access_token']
    }
  end

  def build_media(entry)
    {
      picture: entry.photos.first.url(2560),
      thumbnail: entry.photos.first.url(512, 512)
    }
  end
end
