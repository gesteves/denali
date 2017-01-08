class BufferJob < ApplicationJob
  queue_as :default

  def perform(entry, opts)
    opts.reverse_merge!({ include_link: true, width: 2048 })

    text = opts[:include_link] ? "#{entry.plain_title} #{entry.permalink_url}" : entry.plain_title

    media = {
      picture: entry.photos.first.url(w: opts[:width]),
      thumbnail: entry.photos.first.url(w: 512)
    }

    body = {
      profile_ids: get_profile_ids(opts[:service]),
      text: text,
      media: media,
      shorten: false,
      now: true,
      access_token: ENV['buffer_access_token']
    }

    HTTParty.post('https://api.bufferapp.com/1/updates/create.json', body: body)
  end

  def get_profile_ids(service)
    response = JSON.parse(HTTParty.get("https://api.bufferapp.com/1/profiles.json?access_token=#{ENV['buffer_access_token']}").body)
    response.select { |profile| profile['service'].downcase.match(service) }.map { |profile| profile['id'] }
  end
end
