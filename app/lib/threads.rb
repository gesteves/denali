require 'httparty'
require 'json'

class Threads
  THREADS_API_BASE = 'https://graph.threads.net/v1.0'
  THREADS_BASIC_API_BASE = 'https://graph.threads.net'
  TOKEN_REFRESH_THRESHOLD = 30.days

  # Initializes a new instance of the Threads class.
  # Automatically refreshes the Threads access token if needed and persists to database.
  #
  # @param app_id [String] the Threads App ID.
  # @param app_secret [String] the Threads App Secret.
  # @param social_account [SocialAccount] the SocialAccount record containing Threads credentials.
  # @raise [RuntimeError] if token refresh fails.
  def initialize(app_id:, app_secret:, social_account:)
    @app_id = app_id
    @app_secret = app_secret
    @social_account = social_account
    @threads_user_id = social_account.uid

    refresh_token_if_needed
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
      raise_api_error("Failed to create carousel container", response)
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
      raise_api_error("Failed to check container status", response)
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
      raise_api_error("Failed to publish media", response)
    end
  end

  # Waits for a container to be ready (status = FINISHED) with error handling and timeout.
  #
  # @param container_id [String] the media container ID to wait for.
  # @raise [RuntimeError] if the container status is ERROR, EXPIRED, times out, or has unexpected status.
  def wait_for_container_ready(container_id)
    max_attempts = 60
    attempt = 0

    loop do
      sleep 5 unless Rails.env.test?
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
      raise_api_error("Failed to create media container", response)
    end
  end

  # Parses an API error response and raises the appropriate error class.
  # Raises MetaTransientError for transient errors (which Sidekiq will retry silently),
  # MetaMediaDownloadError for media download failures (error subcode 2207052),
  # and RuntimeError for all other errors (which will be reported to Bugsnag).
  #
  # @param message [String] a description of the failed operation.
  # @param response [HTTParty::Response] the failed HTTP response.
  # @raise [MetaTransientError] if the error is transient.
  # @raise [MetaMediaDownloadError] if the error is a media download failure.
  # @raise [RuntimeError] if the error is not transient.
  def raise_api_error(message, response)
    parsed_body = JSON.parse(response.body) rescue response.body
    is_transient = parsed_body.is_a?(Hash) && parsed_body.dig("error", "is_transient")
    error_subcode = parsed_body.is_a?(Hash) && parsed_body.dig("error", "error_subcode")
    if is_transient
      raise MetaTransientError, "#{message}: #{parsed_body}"
    elsif error_subcode == 2207052
      raise MetaMediaDownloadError, "#{message}: #{parsed_body}"
    else
      raise "#{message}: #{parsed_body}"
    end
  end

  # Returns the access token from the social account.
  #
  # @return [String] the access token.
  # @raise [RuntimeError] if no access token is found.
  def access_token
    token = @social_account.access_token&.strip&.presence
    raise "Threads access token not found in social account." if token.blank?
    token
  end

  # Refreshes the token if it's older than the threshold (53 days).
  # Threads tokens expire after 60 days, so refresh proactively at 53 days.
  #
  # @return [void]
  def refresh_token_if_needed
    return if @social_account.connected_at.blank?
    return if @social_account.connected_at > TOKEN_REFRESH_THRESHOLD.ago

    refresh_token
  end

  # Refreshes a long-lived Threads access token and persists it to the database.
  # Extends the token's validity for another 60 days.
  #
  # @return [Hash] a hash containing :access_token and :expires_in (seconds).
  # @raise [RuntimeError] if the token refresh fails or no token is available.
  def refresh_token
    token_to_refresh = @social_account.access_token&.strip&.presence

    raise "No access token found in social account" if token_to_refresh.blank?

    response = HTTParty.get(
      "#{THREADS_BASIC_API_BASE}/refresh_access_token",
      query: {
        grant_type: 'th_refresh_token',
        access_token: token_to_refresh
      }
    )

    unless response.success?
      raise_api_error("Failed to refresh token", response)
    end

    parsed = JSON.parse(response.body)
    refreshed_token = parsed['access_token'].to_s.strip

    raise "Refreshed token is blank" if refreshed_token.blank?

    # Persist the refreshed token and update connected_at
    @social_account.update!(
      access_token: refreshed_token,
      connected_at: Time.current
    )

    {
      access_token: refreshed_token,
      expires_in: parsed['expires_in']
    }
  end

end

