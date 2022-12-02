require 'open-uri'
require 'json'
class Mastodon
  def initialize(base_url:, bearer_token:)
    @bearer_token = bearer_token
    @base_url = base_url
  end

  def create_status(text:, media_ids: nil)
    endpoint = "#{@base_url}/api/v1/statuses"

    body = {
      status: HTMLEntities.new.decode(text),
      media_ids: media_ids
    }.compact

    headers = {
      'Authorization': "Bearer #{@bearer_token}"
    }

    response = HTTParty.post(endpoint, body: body, headers: headers)

    if response.code == 200
      JSON.parse(response.body)
    else
      raise response.body
    end
  end

  def upload_media(url:, alt_text: nil, focal_point: nil)
  endpoint = "#{@base_url}/api/v2/media"

    body = {
      file: URI.open(url),
      description: HTMLEntities.new.decode(alt_text),
      focus: focal_point&.join(',')
    }.compact

    headers = {
      'Authorization': "Bearer #{@bearer_token}"
    }

    response = HTTParty.post(endpoint, body: body, headers: headers)

    if response.code == 200
      JSON.parse(response.body)
    else
      raise response.body
    end
  end
end
