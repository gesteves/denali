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

  # Posts one or more photos to the Instagram feed.
  # Automatically uses a single image post for one photo, or a carousel for multiple photos.
  #
  # @param photos [Array<Hash>] an array of photo hashes, each with :url and :alt_text.
  # @param caption [String] the caption for the post.
  # @param location_id [String, nil] the location ID for the post.
  # @return [Hash] the parsed response body if successful.
  # @raise [RuntimeError] if the post request fails.
  # @raise [ArgumentError] if photos array is empty or exceeds 10 photos.
  def post(photos:, caption: '', location_id: nil)
    raise ArgumentError, "Photos array cannot be empty" if photos.empty?
    raise ArgumentError, "Photos array cannot exceed 10 photos" if photos.size > 10

    if photos.size == 1
      media_container_id = create_media_container(
        image_url: photos.first[:url],
        caption: caption,
        alt_text: photos.first[:alt_text],
        location_id: location_id
      )
    else
      media_container_id = create_carousel_container(
        photos: photos,
        caption: caption,
        location_id: location_id
      )
    end

    wait_for_container_ready(media_container_id)
    publish_container(media_container_id)
  end

  # Posts a single photo to Instagram Stories.
  # Stories don't support captions or alt text and require 9:16 aspect ratio (1080x1920 recommended).
  #
  # @param photo_url [String] the URL of the photo to post.
  # @return [String] the story container ID.
  # @raise [RuntimeError] if the post request fails.
  def post_story(photo_url:)
    story_container_id = create_story_container(photo_url: photo_url)

    wait_for_container_ready(story_container_id)
    publish_container(story_container_id)
  end

  # Posts a comment on an Instagram media object.
  #
  # @param media_id [String] the Instagram media ID to comment on.
  # @param message [String] the text content of the comment.
  # @return [Hash] the parsed response body containing the comment ID if successful.
  # @raise [ArgumentError] if the message is blank.
  # @raise [RuntimeError] if the comment request fails.
  def post_comment(media_id:, message:)
    raise ArgumentError, "Message cannot be blank" if message.blank?

    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{access_token}"
    }

    response = HTTParty.post(
      "#{INSTAGRAM_GRAPH_API_BASE}/#{media_id}/comments",
      query: { message: message },
      headers: headers
    )

    if response.success?
      JSON.parse(response.body)
    else
      parsed_body = JSON.parse(response.body) rescue response.body
      raise "Failed to post comment: #{parsed_body}"
    end
  end

  private

  # Creates a media container for multiple photos for the Instagram feed as a carousel.
  #
  # @param photos [Array<Hash>] an array of photo hashes, each with :url, :alt_text, and optionally :caption.
  # @param caption [String] the main caption for the carousel post.
  # @param location_id [String, nil] the location ID for the post.
  # @return [String] the carousel container ID.
  # @raise [RuntimeError] if the post request fails.
  def create_carousel_container(photos:, caption: '', location_id: nil)
    raise ArgumentError, "Carousel must contain 2-10 photos" if photos.empty? || photos.size > 10

    # Create media containers for each photo
    media_container_ids = photos.map do |photo|
      create_media_container(
        image_url: photo[:url],
        caption: photo[:caption] || '',
        alt_text: photo[:alt_text]
      )
    end

    # Wait for all individual containers to be ready
    media_container_ids.each do |container_id|
      wait_for_container_ready(container_id)
    end

    body = {
      media_type: 'CAROUSEL',
      children: media_container_ids.join(','),
      caption: caption,
      location_id: location_id
    }.compact

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

  # Creates a media container for a single photo for Instagram Stories.
  # Stories don't support captions or alt text and require 9:16 aspect ratio (1080x1920 recommended).
  #
  # @param photo_url [String] the URL of the photo to post.
  # @return [String] the story container ID.
  # @raise [RuntimeError] if the post request fails.
  def create_story_container(photo_url:)
    body = {
      media_type: 'STORIES',
      image_url: photo_url
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
      raise "Failed to create story container: #{parsed_body}"
    end
  end

  # Checks the status of a media container.
  #
  # @param container_id [String] the media container ID to check.
  # @return [String] the status code (EXPIRED, ERROR, FINISHED, IN_PROGRESS, or PUBLISHED).
  # @raise [RuntimeError] if the status check fails.
  def get_container_status(container_id)
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

  # Publishes a media container to the Instagram feed.
  #
  # @param container_id [String] the media container ID to publish.
  # @return [Hash] the parsed response body if successful.
  # @raise [RuntimeError] if the publish request fails or container is not ready.
  def publish_container(container_id)

    body = {
      creation_id: container_id
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

  # Waits for a container to be ready (status_code = FINISHED) with error handling and timeout.
  #
  # @param container_id [String] the media container ID to wait for.
  # @raise [RuntimeError] if the container status_code is ERROR, EXPIRED, times out, or has unexpected status.
  def wait_for_container_ready(container_id)
    max_attempts = 60
    attempt = 0

    loop do
      sleep 5
      status = get_container_status(container_id)

      case status
      when 'FINISHED'
        return
      when 'PUBLISHED'
        Rails.logger.info "Media container #{container_id} is already published"
        return
      when 'ERROR'
        raise "Media container #{container_id} failed with ERROR status"
      when 'EXPIRED'
        raise "Media container #{container_id} expired before it could be published"
      when 'IN_PROGRESS'
        attempt += 1
        if attempt >= max_attempts
          raise "Media container #{container_id} is still in progress after #{max_attempts * 5} seconds"
        end
      else
        raise "Media container #{container_id} has unexpected status: #{status}"
      end
    end
  end

  # Creates a media container for a single image.
  #
  # @param image_url [String] the URL of the image.
  # @param caption [String] the caption for the image.
  # @param alt_text [String, nil] the alt text for the image (for accessibility).
  # @param location_id [String, nil] the location ID for the post.
  # @return [String] the media container ID.
  # @raise [RuntimeError] if the media container creation fails.
  def create_media_container(image_url:, caption: '', alt_text: nil, location_id: nil)
    body = {
      image_url: image_url,
      caption: caption,
      location_id: location_id,
      alt_text: alt_text
    }.compact

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
end

