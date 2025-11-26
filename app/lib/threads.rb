require 'httparty'
require 'json'

class Threads
  THREADS_API_BASE = 'https://graph.threads.net/v1.0'
  THREADS_BASIC_API_BASE = 'https://graph.threads.net'

  # Initializes a new instance of the Threads class.
  # Automatically refreshes and caches the Threads access token on initialization.
  #
  # @param app_id [String] the Threads App ID.
  # @param app_secret [String] the Threads App Secret.
  # @param threads_user_id [String] the Threads User ID.
  # @raise [RuntimeError] if token refresh fails.
  def initialize(app_id:, app_secret:, threads_user_id:)
    @app_id = app_id
    @app_secret = app_secret
    @threads_user_id = threads_user_id

    # Refresh and cache the token on initialization to ensure we have a fresh token
    begin
      refresh_and_cache_token
    rescue => e
      # If refresh fails, clear cache and raise exception
      clear_cached_token
      raise "Failed to initialize Threads: #{e.message}"
    end
  end

  # Posts one or more photos to Threads.
  # Automatically uses a single image post for one photo, or a carousel for multiple photos.
  #
  # @param photos [Array<Hash>] an array of photo hashes, each with :url and :alt_text.
  # @param caption [String] the caption for the post (max 500 characters).
  # @param topic_tag [String, nil] the topic tag for the post.
  # @param location_id [String, nil] the location ID for the post.
  # @return [Hash] the parsed response body if successful.
  # @raise [RuntimeError] if the post request fails.
  # @raise [ArgumentError] if photos array is empty or exceeds 20 photos.
  def post(photos:, caption: '', topic_tag: nil, location_id: nil)
    raise ArgumentError, "Photos array cannot be empty" if photos.empty?
    raise ArgumentError, "Photos array cannot exceed 20 photos" if photos.size > 20

    if photos.size == 1
      media_container_id = create_media_container(
        image_url: photos.first[:url],
        caption: caption,
        alt_text: photos.first[:alt_text],
        topic_tag: topic_tag,
        location_id: location_id
      )
    else
      media_container_id = create_carousel_container(
        photos: photos,
        caption: caption,
        topic_tag: topic_tag,
        location_id: location_id
      )
    end

    wait_for_container_ready(media_container_id)
    publish_container(media_container_id)
  end

  private

  # Creates a media container for multiple photos for Threads as a carousel.
  #
  # @param photos [Array<Hash>] an array of photo hashes, each with :url, :alt_text, and optionally :caption.
  # @param caption [String] the main caption for the carousel post (max 500 characters).
  # @param topic_tag [String, nil] the topic tag for the post.
  # @param location_id [String, nil] the location ID for the post.
  # @return [String] the carousel container ID.
  # @raise [RuntimeError] if the post request fails.
  def create_carousel_container(photos:, caption: '', topic_tag: nil, location_id: nil)
    raise ArgumentError, "Carousel must contain 2-20 photos" if photos.empty? || photos.size > 20

    # Create media containers for each photo
    media_container_ids = photos.map do |photo|
      create_media_container(
        image_url: photo[:url],
        alt_text: photo[:alt_text],
        is_carousel_item: true
      )
    end

    # Wait for all individual containers to be ready
    media_container_ids.each do |container_id|
      wait_for_container_ready(container_id)
    end

    body = {
      media_type: 'CAROUSEL',
      children: media_container_ids.join(','),
      text: caption,
      topic_tag: topic_tag,
      location_id: location_id
    }.compact

    response = HTTParty.post(
      "#{THREADS_API_BASE}/#{@threads_user_id}/threads",
      body: body,
      query: { access_token: access_token }
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
  # @return [String] the status (EXPIRED, ERROR, FINISHED, IN_PROGRESS, or PUBLISHED).
  # @raise [RuntimeError] if the status check fails.
  def get_container_status(container_id)
    response = HTTParty.get(
      "#{THREADS_API_BASE}/#{container_id}",
      query: {
        fields: 'status,error_message',
        access_token: access_token
      }
    )

    if response.success?
      parsed = JSON.parse(response.body)
      parsed['status']
    else
      parsed_body = JSON.parse(response.body) rescue response.body
      raise "Failed to check container status: #{parsed_body}"
    end
  end

  # Publishes a media container to Threads.
  #
  # @param container_id [String] the media container ID to publish.
  # @return [Hash] the parsed response body if successful.
  # @raise [RuntimeError] if the publish request fails.
  def publish_container(container_id)
    body = {
      creation_id: container_id
    }

    response = HTTParty.post(
      "#{THREADS_API_BASE}/#{@threads_user_id}/threads_publish",
      body: body,
      query: { access_token: access_token }
    )

    if response.success?
      JSON.parse(response.body)
    else
      parsed_body = JSON.parse(response.body) rescue response.body
      raise "Failed to publish media: #{parsed_body}"
    end
  end

  # Waits for a container to be ready (status = FINISHED) with error handling and timeout.
  # Polls up to 60 times (300 seconds / 5 minutes) with 5 second intervals.
  #
  # @param container_id [String] the media container ID to wait for.
  # @raise [RuntimeError] if the container status is ERROR, EXPIRED, times out, or has unexpected status.
  def wait_for_container_ready(container_id)
    max_attempts = 60
    attempt = 0

    loop do
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
        sleep 5
      else
        raise "Media container #{container_id} has unexpected status: #{status}"
      end
    end
  end

  # Creates a media container for a single image.
  #
  # @param image_url [String] the URL of the image.
  # @param caption [String] the caption for the image (max 500 characters).
  # @param alt_text [String, nil] the alt text for the image (for accessibility).
  # @param topic_tag [String, nil] the topic tag for the post.
  # @param is_carousel_item [Boolean] whether this is a carousel item (default: false).
  # @param location_id [String, nil] the location ID for the post.
  # @return [String] the media container ID.
  # @raise [RuntimeError] if the media container creation fails.
  def create_media_container(image_url:, caption: '', alt_text: nil, topic_tag: nil, is_carousel_item: false, location_id: nil)
    body = {
      media_type: 'IMAGE',
      image_url: image_url,
      text: caption,
      alt_text: alt_text,
      topic_tag: topic_tag,
      is_carousel_item: is_carousel_item,
      location_id: location_id
    }.compact

    response = HTTParty.post(
      "#{THREADS_API_BASE}/#{@threads_user_id}/threads",
      body: body,
      query: { access_token: access_token }
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
    "threads:#{@threads_user_id}:access_token"
  end

  # Refreshes a long-lived Threads access token and caches it.
  # Uses the cached token if available, otherwise uses the access token from ENV.
  # Extends the token's validity for another 60 days.
  #
  # @return [Hash] a hash containing :access_token and :expires_in (seconds).
  # @raise [RuntimeError] if the token refresh fails or no token is available.
  def refresh_and_cache_token
    token_to_refresh = get_cached_token&.strip&.presence || ENV['THREADS_ACCESS_TOKEN']&.strip&.presence

    raise "No access token found in cache or ENV['THREADS_ACCESS_TOKEN']" if token_to_refresh.blank?

    response = HTTParty.get(
      "#{THREADS_BASIC_API_BASE}/refresh_access_token",
      query: {
        grant_type: 'th_refresh_token',
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
      raise "Threads access token not found in cache. Token may not have been refreshed during initialization." if token.blank?
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

