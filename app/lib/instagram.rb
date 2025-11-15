require 'httparty'
require 'json'

class Instagram
  INSTAGRAM_GRAPH_API_BASE = 'https://graph.instagram.com/v24.0'
  INSTAGRAM_BASIC_API_BASE = 'https://graph.instagram.com'

  # Initializes a new instance of the Instagram class.
  # Automatically refreshes and caches the Instagram User access token on initialization.
  #
  # @param app_id [String] the Instagram App ID.
  # @param app_secret [String] the Instagram App Secret.
  # @param ig_account_id [String] the Instagram Business Account ID.
  # @raise [RuntimeError] if token refresh fails.
  def initialize(app_id:, app_secret:, ig_account_id:)
    @app_id = app_id
    @app_secret = app_secret
    @ig_account_id = ig_account_id

    # Refresh and cache the token on initialization to ensure we have a fresh token
    begin
      refresh_and_cache_token
    rescue => e
      # If refresh fails, clear cache and raise exception
      clear_cached_token
      raise "Failed to initialize Instagram: #{e.message}"
    end
  end

  # Returns the cache key for the access token.
  #
  # @return [String] the cache key for the access token.
  def access_token_cache_key
    "instagram:#{@ig_account_id}:access_token"
  end

  # Refreshes a long-lived Instagram User access token and caches it.
  # Uses the cached token if available, otherwise uses the access token from ENV.
  # Extends the token's validity for another 60 days.
  #
  # @return [Hash] a hash containing :access_token and :expires_in (seconds).
  # @raise [RuntimeError] if the token refresh fails or no token is available.
  def refresh_and_cache_token
    token_to_refresh = get_cached_token&.strip&.presence || ENV['INSTAGRAM_ACCESS_TOKEN']&.strip&.presence

    raise "No access token found in cache or ENV['INSTAGRAM_ACCESS_TOKEN']" if token_to_refresh.blank?

    response = HTTParty.get(
      "#{INSTAGRAM_BASIC_API_BASE}/refresh_access_token",
      query: {
        grant_type: 'ig_refresh_token',
        access_token: token_to_refresh
      }
    )

    unless response.success?
      parsed_body = JSON.parse(response.body) rescue response.body
      raise "Failed to refresh token: #{parsed_body}"
    end

    parsed = JSON.parse(response.body)
    refreshed_token = parsed['access_token'].to_s.strip

    raise "Refreshed token is blank" if refreshed_token.blank?

    result = {
      access_token: refreshed_token,
      expires_in: parsed['expires_in']
    }

    expires_in_seconds = result[:expires_in] || 60.days.to_i

    # Cache the token with expiration
    Rails.cache.write(access_token_cache_key, refreshed_token, expires_in: expires_in_seconds.seconds)

    # Clear the memoized access token so it will be reloaded from cache
    @access_token = nil

    result
  end

  # Retrieves the access token from cache.
  # The token should always be cached after initialization (via refresh_and_cache_token).
  #
  # @return [String] the access token.
  # @raise [RuntimeError] if no access token is found in cache.
  def access_token
    @access_token ||= begin
      token = get_cached_token&.strip&.presence
      raise "Instagram access token not found in cache. Token may not have been refreshed during initialization." if token.blank?
      token
    end
  end

  # Retrieves the access token from cache or returns nil if not found.
  #
  # @return [String, nil] the cached access token or nil if not found.
  def get_cached_token
    Rails.cache.read(access_token_cache_key)
  end

  # Removes the access token from cache.
  #
  # @return [void]
  def clear_cached_token
    Rails.cache.delete(access_token_cache_key)
  end

  # Posts a single photo to the Instagram feed.
  #
  # @param photo_url [String] the URL of the photo to post.
  # @param caption [String] the caption for the photo.
  # @param alt_text [String] the alt text for the photo (for accessibility).
  #   Supported for image posts as of March 24, 2025.
  # @return [Hash] the parsed response body if successful.
  # @raise [RuntimeError] if the post request fails.
  def post_photo(photo_url:, caption: '', alt_text: nil)
    # Create media container
    media_container_id = create_media_container(
      image_url: photo_url,
      caption: caption,
      alt_text: alt_text
    )

    # Publish the media
    publish_media(media_container_id)
  end

  # Posts multiple photos to the Instagram feed as a carousel.
  #
  # @param photos [Array<Hash>] an array of photo hashes, each with :url, :alt_text, and optionally :caption.
  # @param caption [String] the main caption for the carousel post.
  # @return [Hash] the parsed response body if successful.
  # @raise [RuntimeError] if the post request fails.
  def post_carousel(photos:, caption: '')
    raise ArgumentError, "Carousel must contain 2-10 photos" if photos.empty? || photos.size > 10

    # Create media containers for each photo
    media_container_ids = photos.map do |photo|
      create_media_container(
        image_url: photo[:url],
        caption: photo[:caption] || '',
        alt_text: photo[:alt_text]
      )
    end

    # Create carousel container
    carousel_container_id = create_carousel_container(
      children: media_container_ids,
      caption: caption
    )

    # Publish the carousel
    publish_media(carousel_container_id)
  end

  private

  # Creates a media container for a single image.
  #
  # @param image_url [String] the URL of the image.
  # @param caption [String] the caption for the image.
  # @param alt_text [String, nil] the alt text for the image (for accessibility).
  # @return [String] the media container ID.
  # @raise [RuntimeError] if the media container creation fails.
  def create_media_container(image_url:, caption: '', alt_text: nil)
    body = {
      image_url: image_url,
      caption: caption
    }
    body[:alt_text] = alt_text if alt_text.present?

    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{access_token}"
    }

    response = HTTParty.post(
      "#{INSTAGRAM_GRAPH_API_BASE}/#{@ig_account_id}/media",
      body: body.to_json,
      headers: headers
    )

    if response.success?
      JSON.parse(response.body)['id']
    else
      parsed_body = JSON.parse(response.body) rescue response.body
      raise "Failed to create media container: #{parsed_body}"
    end
  end

  # Creates a carousel container with multiple media items.
  #
  # @param children [Array<String>] an array of media container IDs.
  # @param caption [String] the caption for the carousel.
  # @return [String] the carousel container ID.
  # @raise [RuntimeError] if the carousel container creation fails.
  def create_carousel_container(children:, caption: '')
    body = {
      media_type: 'CAROUSEL',
      children: children.join(','),
      caption: caption
    }

    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{access_token}"
    }

    response = HTTParty.post(
      "#{INSTAGRAM_GRAPH_API_BASE}/#{@ig_account_id}/media",
      body: body.to_json,
      headers: headers
    )

    if response.success?
      JSON.parse(response.body)['id']
    else
      parsed_body = JSON.parse(response.body) rescue response.body
      raise "Failed to create carousel container: #{parsed_body}"
    end
  end

  # Checks the status of a media container.
  #
  # @param container_id [String] the media container ID to check.
  # @return [String] the status code (EXPIRED, ERROR, FINISHED, IN_PROGRESS, or PUBLISHED).
  # @raise [RuntimeError] if the status check fails.
  def check_container_status(container_id)
    headers = {
      'Authorization' => "Bearer #{access_token}"
    }

    response = HTTParty.get(
      "#{INSTAGRAM_GRAPH_API_BASE}/#{container_id}",
      query: { fields: 'status_code' },
      headers: headers
    )

    if response.success?
      parsed = JSON.parse(response.body)
      parsed['status_code']
    else
      parsed_body = JSON.parse(response.body) rescue response.body
      raise "Failed to check container status: #{parsed_body}"
    end
  end

  # Waits for a media container to be ready for publishing.
  # Polls the container status up to 10 times, waiting 5 seconds between checks.
  #
  # @param container_id [String] the media container ID to wait for.
  # @param max_attempts [Integer] maximum number of status checks (default: 10).
  # @param wait_seconds [Integer] seconds to wait between checks (default: 5).
  # @return [void]
  # @raise [RuntimeError] if the container doesn't become ready or encounters an error.
  def wait_for_container_ready(container_id, max_attempts: 10, wait_seconds: 5)
    max_attempts.times do |attempt|
      status = check_container_status(container_id)

      case status
      when 'FINISHED'
        return # Container is ready
      when 'PUBLISHED'
        return # Already published
      when 'ERROR'
        raise "Media container failed with ERROR status"
      when 'EXPIRED'
        raise "Media container expired before it could be published"
      when 'IN_PROGRESS'
        # Continue waiting
        sleep(wait_seconds) unless attempt == max_attempts - 1
      else
        raise "Unknown container status: #{status}"
      end
    end

    raise "Media container did not become ready after #{max_attempts} attempts"
  end

  # Publishes a media container to the Instagram feed.
  # Waits for the container to be ready before attempting to publish.
  #
  # @param creation_id [String] the media container ID to publish.
  # @return [Hash] the parsed response body if successful.
  # @raise [RuntimeError] if the publish request fails or container is not ready.
  def publish_media(creation_id)
    # Wait for the container to be ready before publishing
    wait_for_container_ready(creation_id)

    body = {
      creation_id: creation_id
    }

    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{access_token}"
    }

    response = HTTParty.post(
      "#{INSTAGRAM_GRAPH_API_BASE}/#{@ig_account_id}/media_publish",
      body: body.to_json,
      headers: headers
    )

    if response.success?
      JSON.parse(response.body)
    else
      parsed_body = JSON.parse(response.body) rescue response.body
      raise "Failed to publish media: #{parsed_body}"
    end
  end
end

