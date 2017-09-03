class BufferJob < ApplicationJob
  private

  def get_profile_ids(service, service_type = 'profile')
    profiles = Rails.cache.fetch('buffer:profiles', expires_in: 1.hour) do
      response = HTTParty.get("https://api.bufferapp.com/1/profiles.json?access_token=#{ENV['buffer_access_token']}")
      if response.code >= 400
        raise response.body
      else
        response.body
      end
    end
    profiles = JSON.parse(response.body)
    profiles.select { |profile| profile['service'].downcase.match(service) && profile['service_type'].downcase.match(service_type) }.map { |profile| profile['id'] }
  end

  def post_to_buffer(profile_ids, text, image_url, thumbnail_url)
    media = { picture: image_url, thumbnail: thumbnail_url }
    body = {
      profile_ids: profile_ids,
      text: text,
      media: media,
      shorten: false,
      access_token: ENV['buffer_access_token']
    }

    response = HTTParty.post('https://api.bufferapp.com/1/updates/create.json', body: body)
    if response.code >= 400
      raise response.body
    end
  end
end
