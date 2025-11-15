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

  # Posts a single photo to Threads.
  #
  # @param photo_url [String] the URL of the photo to post.
  # @param caption [String] the caption for the photo (max 500 characters).
  # @param alt_text [String] the alt text for the photo (for accessibility).
  # @param latitude [Float, nil] the latitude for location tagging.
  # @param longitude [Float, nil] the longitude for location tagging.
  # @param topic_tag [String, nil] the topic tag for the post.
  # @return [Hash] the parsed response body if successful.
  # @raise [RuntimeError] if the post request fails.
  def post_photo(photo_url:, caption: '', alt_text: nil, latitude: nil, longitude: nil, topic_tag: nil)
    # Search for location if coordinates are provided
    # Continue without location if search fails
    location_id = nil
    if latitude.present? && longitude.present?
      begin
        location_id = search_location(latitude: latitude, longitude: longitude)
      rescue => e
        Rails.logger.warn "Threads location search failed: #{e.message}. Continuing without location tagging."
      end
    end

    # Create media container
    media_container_id = create_media_container(
      image_url: photo_url,
      caption: caption,
      alt_text: alt_text,
      location_id: location_id,
      topic_tag: topic_tag
    )

    # Publish the media
    publish_media(media_container_id)
  end

  # Posts multiple photos to Threads as a carousel.
  #
  # @param photos [Array<Hash>] an array of photo hashes, each with :url, :alt_text, and optionally :caption, :latitude, :longitude.
  # @param caption [String] the main caption for the carousel post (max 500 characters).
  # @param topic_tag [String, nil] the topic tag for the post.
  # @return [Hash] the parsed response body if successful.
  # @raise [RuntimeError] if the post request fails.
  def post_carousel(photos:, caption: '', topic_tag: nil)
    raise ArgumentError, "Carousel must contain 2-20 photos" if photos.empty? || photos.size > 20

    # Use location from first photo for the carousel (Threads carousels use a single location)
    # Continue without location if search fails
    first_photo = photos.first
    location_id = nil
    if first_photo[:latitude].present? && first_photo[:longitude].present?
      begin
        location_id = search_location(latitude: first_photo[:latitude], longitude: first_photo[:longitude])
      rescue => e
        Rails.logger.warn "Threads location search failed: #{e.message}. Continuing without location tagging."
      end
    end

    # Create media containers for each photo
    media_container_ids = photos.map do |photo|
      create_media_container(
        image_url: photo[:url],
        caption: photo[:caption] || '',
        alt_text: photo[:alt_text],
        is_carousel_item: true
      )
    end

    # Wait for all containers to be ready before creating carousel
    # Threads API recommends waiting ~30 seconds on average
    sleep(30)

    # Create carousel container with location and topic
    carousel_container_id = create_carousel_container(
      children: media_container_ids,
      caption: caption,
      location_id: location_id,
      topic_tag: topic_tag
    )

    # Publish the carousel
    publish_media(carousel_container_id)
  end

  private

  # Searches for a location using latitude and longitude coordinates.
  #
  # @param latitude [Float] the latitude of the location.
  # @param longitude [Float] the longitude of the location.
  # @return [String, nil] the location ID if found, nil otherwise.
  # @raise [RuntimeError] if the location search fails.
  def search_location(latitude:, longitude:)
    response = HTTParty.get(
      "#{THREADS_API_BASE}/location_search",
      query: {
        latitude: latitude,
        longitude: longitude,
        access_token: access_token
      }
    )

    unless response.success?
      parsed_body = JSON.parse(response.body) rescue response.body
      raise "Failed to search location: #{parsed_body}"
    end

    parsed = JSON.parse(response.body)
    locations = parsed['data'] || []

    # Return the first location ID if available
    locations.first&.dig('id')&.to_s
  end

  # Creates a media container for a single image.
  #
  # @param image_url [String] the URL of the image.
  # @param caption [String] the caption for the image (max 500 characters).
  # @param alt_text [String, nil] the alt text for the image (for accessibility).
  # @param location_id [String, nil] the location ID for location tagging.
  # @param topic_tag [String, nil] the topic tag for the post.
  # @param is_carousel_item [Boolean] whether this is a carousel item (default: false).
  # @return [String] the media container ID.
  # @raise [RuntimeError] if the media container creation fails.
  def create_media_container(image_url:, caption: '', alt_text: nil, location_id: nil, topic_tag: nil, is_carousel_item: false)
    body = {
      media_type: 'IMAGE',
      image_url: image_url,
      text: caption
    }
    body[:is_carousel_item] = true if is_carousel_item
    body[:alt_text] = alt_text if alt_text.present?
    body[:location_id] = location_id if location_id.present?
    body[:topic_tag] = topic_tag if topic_tag.present?

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

  # Creates a carousel container with multiple media items.
  #
  # @param children [Array<String>] an array of media container IDs.
  # @param caption [String] the caption for the carousel (max 500 characters).
  # @param location_id [String, nil] the location ID for location tagging.
  # @param topic_tag [String, nil] the topic tag for the post.
  # @return [String] the carousel container ID.
  # @raise [RuntimeError] if the carousel container creation fails.
  def create_carousel_container(children:, caption: '', location_id: nil, topic_tag: nil)
    body = {
      media_type: 'CAROUSEL',
      children: children.join(','),
      text: caption
    }
    body[:location_id] = location_id if location_id.present?
    body[:topic_tag] = topic_tag if topic_tag.present?

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

  # Publishes a media container to Threads.
  # Waits for the container to be ready before attempting to publish.
  # Threads API recommends waiting ~30 seconds before publishing.
  #
  # @param creation_id [String] the media container ID to publish.
  # @return [Hash] the parsed response body if successful.
  # @raise [RuntimeError] if the publish request fails.
  def publish_media(creation_id)
    # Wait for the container to be ready before publishing
    # Threads API recommends waiting ~30 seconds on average
    sleep(30)

    body = {
      creation_id: creation_id
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
end

