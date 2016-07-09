class BufferJob < ApplicationJob
  queue_as :default

  def perform(entry, service)
    HTTParty.post('https://api.bufferapp.com/1/updates/create.json', body: build_body(entry, service))
  end

  def build_body(entry, service)
    body = {
      profile_ids: get_profile_ids(service),
      text: build_text(entry),
      shorten: false,
      now: true,
      access_token: ENV['buffer_access_token']
    }
    body[:media] = build_media(entry)
    body
  end

  def build_text(entry)
    "#{entry.plain_title} #{entry.permalink_url}"
  end

  def build_media(entry)
    {
      picture: entry.photos.first.url(w: 2048),
      thumbnail: entry.photos.first.url(w: 512)
    }
  end

  def get_profile_ids(service)
    response = JSON.parse(HTTParty.get("https://api.bufferapp.com/1/profiles.json?access_token=#{ENV['buffer_access_token']}").body)
    response.select { |profile| profile['service'].downcase.match(service) }.map { |profile| profile['id'] }
  end
end
