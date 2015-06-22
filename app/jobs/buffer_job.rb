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
      text: build_text(entry),
      shorten: false,
      media: build_media(entry),
      now: true,
      access_token: ENV['buffer_access_token']
    }
  end

  def build_text(entry)
    text = entry.formatted_title
    text += "\n\n#{entry.plain_body}" unless entry.body.blank?
    text += "\n\n#{permalink_url(entry)}"
  end

  def build_media(entry)
    {
      picture: entry.photos.first.original_url,
      thumbnail: entry.photos.first.url(512, 512)
    }
  end
end
