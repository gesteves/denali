require 'open-uri'
require 'json'
class Mastodon
  def initialize(base_url:, bearer_token:)
    @bearer_token = bearer_token
    @base_url = base_url
  end

  def self.from_social_account(social_account)
    new(
      base_url: social_account.server_url,
      bearer_token: social_account.access_token
    )
  end

  def create_status(text:, media_ids: [], sensitive: false, spoiler_text: nil, visibility: 'public', language: 'en', scheduled_at: nil)
    endpoint = "#{@base_url}/api/v1/statuses"

    body = {
      status: HTMLEntities.new.decode(text),
      media_ids: media_ids.presence,
      spoiler_text: spoiler_text.presence,
      sensitive: sensitive,
      visibility: visibility,
      language: language,
      scheduled_at: scheduled_at
    }.compact

    headers = {
      'Authorization': "Bearer #{@bearer_token}",
      'Idempotency-Key': Digest::SHA256.base64digest(body.to_s)
    }

    response = HTTParty.post(endpoint, body: body, headers: headers)

    if response.code == 200
      JSON.parse(response.body)
    else
      Rails.logger.error("[Mastodon] create_status failed: status=#{response.code}")
      Rails.logger.error("[Mastodon] Response body: #{response.body.truncate(500)}")
      raise "Mastodon create_status failed with status #{response.code}"
    end
  end

  def upload_media(url:, alt_text:, focal_point: nil)
    endpoint = "#{@base_url}/api/v2/media"
    
    body = {
      file: URI.open(url),
      description: HTMLEntities.new.decode(ActiveSupport::Inflector.transliterate(alt_text)),
      focus: focal_point&.join(',')
    }.compact

    headers = {
      'Authorization': "Bearer #{@bearer_token}"
    }

    response = HTTParty.post(endpoint, body: body, headers: headers, stream_body: false)

    if response.code == 200 || response.code == 202
      JSON.parse(response.body)
    else
      Rails.logger.error("[Mastodon] upload_media failed: status=#{response.code}, url=#{url}")
      Rails.logger.error("[Mastodon] Response body: #{response.body.truncate(500)}")
      raise "Mastodon upload_media failed with status #{response.code}"
    end
  end
end
