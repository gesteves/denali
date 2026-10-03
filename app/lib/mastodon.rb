require 'open-uri'
require 'json'

class Mastodon
  MAX_MEDIA_ATTACHMENTS = 4
  MEDIA_POLL_ATTEMPTS = 15
  MEDIA_POLL_INTERVAL = 2 # seconds

  # The server refused the access token (401) or the account may not do this (403). Retrying won't
  # help until the account is reconnected in the admin.
  class AuthenticationError < StandardError; end

  # The server refused the request itself (422), such as a status over the instance's length
  # limit. It will refuse it the same way every time.
  class PermanentError < StandardError; end

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
  # @param idempotency_key [String, nil] identifies this post across retries, so the
  #   server returns the original status instead of posting it twice. Mastodon
  #   remembers keys for an hour. Defaults to a digest of the text.
  # @return [Hash] the parsed response from the API.
  # @raise [AuthenticationError, PermanentError] if the server refuses it for good.
  # @raise [RuntimeError] if the API request fails otherwise.
  def create_status(text:, media_ids: [], sensitive: false, spoiler_text: nil, visibility: 'public', language: 'en', scheduled_at: nil, idempotency_key: nil)
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

    # Not a digest of the whole body: a retry re-uploads the media and gets new
    # media IDs, which would change the key and post a duplicate.
    headers = auth_headers.merge('Idempotency-Key': idempotency_key || Digest::SHA256.base64digest(body[:status]))

    response = HTTParty.post(endpoint, body: body, headers: headers)

    if response.code == 200
      JSON.parse(response.body)
    else
      raise_api_error('create_status', response)
    end
  end

  # Uploads media to Mastodon for later attachment to a status.
  #
  # @param url [String] the URL of the media file to upload.
  # @param alt_text [String, nil] the alt text description for the media.
  # @param focal_point [Array<Float>, nil] the focal point as [x, y] coordinates (-1.0 to 1.0).
  # @return [Hash] the parsed response from the API containing the media ID. If the
  #   server is still processing the file, waits until it's ready to attach.
  # @raise [AuthenticationError, PermanentError] if the server refuses it for good.
  # @raise [RuntimeError] if the media fetch, upload, or processing fails otherwise.
  def upload_media(url:, alt_text:, focal_point: nil)
    endpoint = "#{@base_url}/api/v2/media"

    file = begin
      URI.open(url)
    rescue OpenURI::HTTPError, Errno::ENOENT, SocketError => e
      raise "Failed to fetch media from #{url}: #{e.message}"
    end

    # Mastodon takes UTF-8 descriptions; photos whose alt text hasn't been
    # written yet go up without one.
    body = {
      file: file,
      description: HTMLEntities.new.decode(alt_text.to_s).presence,
      focus: focal_point&.join(',')
    }.compact

    response = HTTParty.post(endpoint, body: body, headers: auth_headers, stream_body: false)

    if response.code == 200
      JSON.parse(response.body)
    elsif response.code == 202
      wait_for_media_processing(JSON.parse(response.body)['id'])
    else
      raise_api_error('upload_media', response, url: url)
    end
  end

  private

  # Raises the error that says whether trying again could help, with what the server said: the
  # status code alone doesn't say why.
  def raise_api_error(doing, response, url: nil)
    message = "Mastodon #{doing} failed with status #{response.code}: #{response.body.to_s.truncate(500)}"
    Rails.logger.error("[Mastodon] #{message}#{" (#{url})" if url}")

    case response.code
    when 401, 403 then raise AuthenticationError, message
    when 422 then raise PermanentError, message
    else raise message
    end
  end

  def auth_headers
    { 'Authorization': "Bearer #{@bearer_token}" }
  end

  # A 202 from the upload means the server accepted the file but hasn't finished
  # processing it, and a status can't attach media until it has. The media
  # endpoint answers 206 while processing and 200 once it's ready.
  def wait_for_media_processing(id)
    MEDIA_POLL_ATTEMPTS.times do
      sleep MEDIA_POLL_INTERVAL
      response = HTTParty.get("#{@base_url}/api/v1/media/#{id}", headers: auth_headers)
      return JSON.parse(response.body) if response.code == 200
      raise "Mastodon media #{id} failed processing with status #{response.code}" unless response.code == 206
    end
    raise "Mastodon media #{id} was still processing after #{MEDIA_POLL_ATTEMPTS * MEDIA_POLL_INTERVAL} seconds"
  end
end
