class BufferJob < ApplicationJob
  private

  def get_profile_ids(service)
    response = HTTParty.get("https://api.bufferapp.com/1/profiles.json?access_token=#{ENV['buffer_access_token']}")
    if response.code >= 400
      raise response.body
    else
      profiles = JSON.parse(response.body)
      profiles.select { |profile| profile['service'].downcase.match(service) }.map { |profile| profile['id'] }
    end
  end

  def post_to_buffer(service, text, image_url, thumbnail_url)
    media = { picture: image_url, thumbnail: thumbnail_url }
    body = {
      profile_ids: get_profile_ids(service),
      text: text,
      media: media,
      shorten: false,
      now: true,
      access_token: ENV['buffer_access_token']
    }

    response = HTTParty.post('https://api.bufferapp.com/1/updates/create.json', body: body)
    if response.code >= 400
      raise response.body
    end
  end
end
