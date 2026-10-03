require 'httparty'
require 'json'

class Instagram
  INSTAGRAM_GRAPH_API_BASE = 'https://graph.instagram.com/v24.0'
  INSTAGRAM_BASIC_API_BASE = 'https://graph.instagram.com'

  # Tokens expire after 60 days; refresh when older than this many days
  TOKEN_REFRESH_THRESHOLD_DAYS = 30

  # The most photos a carousel can hold.
  MAX_CAROUSEL_PHOTOS = 10

  # Initializes a new instance of the Instagram class.
  # Refreshes the token if it's expiring soon.
  #
  # @param app_id [String] the Instagram App ID.
  # @param app_secret [String] the Instagram App Secret.
  # @param social_account [SocialAccount] the social account with Instagram credentials.
  def initialize(app_id:, app_secret:, social_account:)
    @app_id = app_id
    @app_secret = app_secret
    @social_account = social_account
    @ig_account_id = social_account.uid

    # Only refresh if token is expiring soon.
    refresh_token_if_needed
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

  # A feed post is made in steps, which InstagramJob (see MetaShareJob) spreads across attempts:
  # create a container (for a carousel, one per photo and then one that holds them), wait for
  # container_status to say Meta has fetched and processed the images, then publish_container.
  #
  # Creates a container for a single photo, ready to publish once Meta has processed it.
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

    Rails.logger.info("[Instagram] Creating media container with image_url: #{image_url}")

    response = HTTParty.post(
      "#{INSTAGRAM_GRAPH_API_BASE}/#{@ig_account_id}/media",
      body: body.to_json,
      headers: headers
    )

    if response.success?
      JSON.parse(response.body)['id']
    else
      Rails.logger.error("[Instagram] Failed to create media container. image_url: #{image_url}")
      raise_api_error("Failed to create media container", response)
    end
  end

  # Creates a container for each photo of a carousel. The carousel's own container can only be
  # made once Meta has processed all of these.
  #
  # @param photos [Array<Hash>] an array of photo hashes, each with :url, :alt_text, and optionally :caption.
  # @return [Array<String>] the containers' IDs, in the photos' order.
  # @raise [ArgumentError] if there are fewer than 2 photos or more than MAX_CAROUSEL_PHOTOS.
  def create_carousel_items(photos)
    raise ArgumentError, "Carousel must contain 2-#{MAX_CAROUSEL_PHOTOS} photos" if photos.size < 2 || photos.size > MAX_CAROUSEL_PHOTOS

    photos.map do |photo|
      create_media_container(
        image_url: photo[:url],
        caption: photo[:caption] || '',
        alt_text: photo[:alt_text]
      )
    end
  end

  # Creates the container that holds a carousel's photos, once each of theirs is processed.
  #
  # @param children [Array<String>] the photos' container IDs, from create_carousel_items.
  # @param caption [String] the main caption for the carousel post.
  # @param location_id [String, nil] the location ID for the post.
  # @return [String] the carousel container ID.
  # @raise [RuntimeError] if the post request fails.
  def create_carousel_container(children:, caption: '', location_id: nil)
    body = {
      media_type: 'CAROUSEL',
      children: children.join(','),
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

  # Checks how far Meta has got with a container.
  #
  # @param container_id [String] the media container ID to check.
  # @return [Hash] 'code': EXPIRED, ERROR, FINISHED, IN_PROGRESS or PUBLISHED; 'error': what
  #   Meta says went wrong, for an ERROR.
  # @raise [RuntimeError] if the status check fails.
  def container_status(container_id)
    headers = {
      'Authorization' => "Bearer #{access_token}"
    }

    response = HTTParty.get(
      "#{INSTAGRAM_GRAPH_API_BASE}/#{container_id}",
      query: { fields: 'status_code,status' },
      headers: headers
    )

    if response.success?
      parsed = JSON.parse(response.body)
      { 'code' => parsed['status_code'], 'error' => parsed['status'] }
    else
      raise_api_error("Failed to check container status", response)
    end
  end

  # Publishes a media container to the Instagram feed.
  #
  # @param container_id [String] the media container ID to publish.
  # @return [Hash] the parsed response body, with the new post's media 'id'.
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
  # A failed refresh doesn't stop the post: the token is still good for weeks after it's due one,
  # and the next post tries again. Once it really has expired, the post itself fails with a
  # MetaAuthError.
  #
  # @return [void]
  def refresh_token_if_needed
    return if @social_account.connected_at.blank?
    return unless @social_account.connected_at < TOKEN_REFRESH_THRESHOLD_DAYS.days.ago

    refresh_token
  rescue StandardError => e
    Rails.logger.warn("[Instagram] Couldn't refresh the token for #{@ig_account_id}; using the current one: #{e.message}")
    Bugsnag.notify(e)
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

    Rails.logger.info("[Instagram] Creating story container with image_url: #{photo_url}")

    response = HTTParty.post(
      "#{INSTAGRAM_GRAPH_API_BASE}/#{@ig_account_id}/media",
      body: body.to_json,
      headers: headers
    )

    if response.success?
      JSON.parse(response.body)['id']
    else
      Rails.logger.error("[Instagram] Failed to create story container. image_url: #{photo_url}")
      raise_api_error("Failed to create story container", response)
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
      status = container_status(container_id)['code']

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

  # Parses an API error response and raises the appropriate error class.
  # Raises MetaTransientError for transient errors (which Sidekiq will retry silently),
  # MetaAuthError for a token Meta refuses (code 190), MetaMediaDownloadError for media download
  # failures (error subcode 2207052), MetaCaptionTooLongError for an over-long caption, and
  # RuntimeError for all other errors (which will be reported to Bugsnag).
  #
  # @param message [String] a description of the failed operation.
  # @param response [HTTParty::Response] the failed HTTP response.
  # @raise [MetaTransientError] if the error is transient.
  # @raise [MetaMediaDownloadError] if the error is a media download failure.
  # @raise [RuntimeError] if the error is not transient.
  def raise_api_error(message, response)
    parsed_body = JSON.parse(response.body) rescue response.body
    # Meta's errors are usually an object, but not always; anything else is just a message.
    error = parsed_body.is_a?(Hash) && parsed_body['error'].is_a?(Hash) ? parsed_body['error'] : {}
    if error['is_transient']
      raise MetaTransientError, "#{message}: #{parsed_body}"
    elsif error['code'] == 190
      raise MetaAuthError, "#{message}: #{parsed_body}"
    elsif error['error_subcode'] == 2207052
      raise MetaMediaDownloadError, "#{message}: #{parsed_body}"
    elsif error['message'].to_s.match?(/must be at most \d+ characters long/i)
      raise MetaCaptionTooLongError, "#{message}: #{parsed_body}"
    else
      raise "#{message}: #{parsed_body}"
    end
  end
end
