require 'httparty'
require 'json'

class Instagram
  INSTAGRAM_GRAPH_API_BASE = 'https://graph.instagram.com/v24.0'
  INSTAGRAM_BASIC_API_BASE = 'https://graph.instagram.com'

  # Tokens expire after 60 days; refresh when older than this many days
  TOKEN_REFRESH_THRESHOLD_DAYS = 30

  # Initializes a new instance of the Instagram class.
  # Refreshes the token if it's expiring soon.
  #
  # @param app_id [String] the Instagram App ID.
  # @param app_secret [String] the Instagram App Secret.
  # @param social_account [SocialAccount] the social account with Instagram credentials.
  # @raise [RuntimeError] if token refresh fails.
  def initialize(app_id:, app_secret:, social_account:)
    @app_id = app_id
    @app_secret = app_secret
    @social_account = social_account
    @ig_account_id = social_account.uid

    # Only refresh if token is expiring soon.
    refresh_token_if_needed
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
      raise_api_error("Failed to post comment", response)
    end
  end

  private

  # Returns the access token from the social account.
  #
  # @return [String] the access token.
  def access_token
    @social_account.access_token
  end

  # Checks if the token needs to be refreshed and refreshes it if necessary.
  # Tokens are refreshed if connected_at is more than TOKEN_REFRESH_THRESHOLD_DAYS days ago.
  #
  # @return [void]
  def refresh_token_if_needed
    return if @social_account.connected_at.blank?
    return unless @social_account.connected_at < TOKEN_REFRESH_THRESHOLD_DAYS.days.ago

    refresh_token
  end

  # Refreshes a long-lived Instagram User access token and persists it to the database.
  # Extends the token's validity for another 60 days.
  #
  # @return [void]
  # @raise [RuntimeError] if the token refresh fails.
  def refresh_token
    response = HTTParty.get(
      "#{INSTAGRAM_BASIC_API_BASE}/refresh_access_token",
      query: {
        grant_type: 'ig_refresh_token',
        access_token: @social_account.access_token
      }
    )

    unless response.success?
      parsed_body = JSON.parse(response.body) rescue response.body
      Rails.logger.error("[Instagram] Token refresh failed: #{parsed_body}")
      raise_api_error("Failed to refresh Instagram token", response)
    end

    parsed = JSON.parse(response.body)
    new_token = parsed['access_token'].to_s.strip

    raise "Refreshed token is blank" if new_token.blank?

    @social_account.update!(access_token: new_token, connected_at: Time.current)
    Rails.logger.info("[Instagram] Token refreshed for account #{@ig_account_id}")
  end

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
      raise_api_error("Failed to create carousel container", response)
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
      raise_api_error("Failed to create story container", response)
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
      raise_api_error("Failed to check container status", response)
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
      raise_api_error("Failed to publish media", response)
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
      raise_api_error("Failed to create media container", response)
    end
  end

  # Parses an API error response and raises the appropriate error class.
  # Raises MetaTransientError for transient errors (which Sidekiq will retry silently)
  # and RuntimeError for all other errors (which will be reported to Bugsnag).
  #
  # @param message [String] a description of the failed operation.
  # @param response [HTTParty::Response] the failed HTTP response.
  # @raise [MetaTransientError] if the error is transient.
  # @raise [RuntimeError] if the error is not transient.
  def raise_api_error(message, response)
    parsed_body = JSON.parse(response.body) rescue response.body
    is_transient = parsed_body.is_a?(Hash) && parsed_body.dig("error", "is_transient")
    if is_transient
      raise MetaTransientError, "#{message}: #{parsed_body}"
    else
      raise "#{message}: #{parsed_body}"
    end
  end
end
