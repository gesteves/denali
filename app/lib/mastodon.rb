require 'open-uri'
require 'json'

class Mastodon
  MAX_MEDIA_ATTACHMENTS = 4

  # Initializes a new Mastodon API client.
  #
  # @param base_url [String] the base URL of the Mastodon instance (e.g., 'https://mastodon.social').
  # @param bearer_token [String] the OAuth bearer token for authentication.
  def initialize(base_url:, bearer_token:)
    @bearer_token = bearer_token
    @base_url = base_url
  end

  # Creates a Mastodon instance from a SocialAccount.
  #
  # @param social_account [SocialAccount] the social account to use.
  # @return [Mastodon] a new Mastodon instance.
  def self.from_social_account(social_account)
    new(
      base_url: social_account.server_url,
      bearer_token: social_account.access_token
    )
  end

  # Creates a new status (toot) on Mastodon.
  #
  # @param text [String] the text content of the status.
  # @param media_ids [Array<String>] an array of media IDs to attach.
  # @param sensitive [Boolean] whether the status contains sensitive content.
  # @param spoiler_text [String, nil] the content warning text.
  # @param visibility [String] the visibility level ('public', 'unlisted', 'private', 'direct').
  # @param language [String] the ISO 639-1 language code.
  # @param scheduled_at [String, nil] ISO 8601 datetime for scheduling.
  # @return [Hash] the parsed response from the API.
  # @raise [RuntimeError] if the API request fails.
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

  # Uploads media to Mastodon for later attachment to a status.
  #
  # @param url [String] the URL of the media file to upload.
  # @param alt_text [String] the alt text description for the media.
  # @param focal_point [Array<Float>, nil] the focal point as [x, y] coordinates (-1.0 to 1.0).
  # @return [Hash] the parsed response from the API containing the media ID.
  # @raise [RuntimeError] if the media fetch or upload fails.
  def upload_media(url:, alt_text:, focal_point: nil)
    endpoint = "#{@base_url}/api/v2/media"

    file = begin
      URI.open(url)
    rescue OpenURI::HTTPError, Errno::ENOENT, SocketError => e
      raise "Failed to fetch media from #{url}: #{e.message}"
    end

    body = {
      file: file,
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
