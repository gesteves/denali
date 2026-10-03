require 'httparty'
require 'json'

class Threads
  THREADS_API_BASE = 'https://graph.threads.net/v1.0'
  THREADS_BASIC_API_BASE = 'https://graph.threads.net'
  TOKEN_REFRESH_THRESHOLD = 30.days

  # The most photos a carousel can hold.
  MAX_CAROUSEL_PHOTOS = 20

  # Initializes a new instance of the Threads class.
  # Automatically refreshes the Threads access token if needed and persists to database.
  #
  # @param app_id [String] the Threads App ID.
  # @param app_secret [String] the Threads App Secret.
  # @param social_account [SocialAccount] the SocialAccount record containing Threads credentials.
  def initialize(app_id:, app_secret:, social_account:)
    @app_id = app_id
    @app_secret = app_secret
    @social_account = social_account
    @threads_user_id = social_account.uid

    refresh_token_if_needed
  end

  # A post is made in steps, which ThreadsJob (see MetaShareJob) spreads across attempts: create a
  # container (for a carousel, one per photo and then one that holds them), wait for
  # container_status to say Meta has fetched and processed the images, then publish_container.
  #
  # Creates a container for a single photo, or for one photo of a carousel.
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

    Rails.logger.info("[Threads] Creating media container with image_url: #{image_url}")

    response = HTTParty.post(
      "#{THREADS_API_BASE}/#{@threads_user_id}/threads",
      body: body,
      query: { access_token: access_token }
    )

    if response.success?
      JSON.parse(response.body)['id']
    else
      Rails.logger.error("[Threads] Failed to create media container. image_url: #{image_url}")
      raise_api_error("Failed to create media container", response)
    end
  end

  # Creates a container for each photo of a carousel. The carousel's own container can only be
  # made once Meta has processed all of these.
  #
  # @param photos [Array<Hash>] an array of photo hashes, each with :url and :alt_text.
  # @return [Array<String>] the containers' IDs, in the photos' order.
  # @raise [ArgumentError] if there are fewer than 2 photos or more than MAX_CAROUSEL_PHOTOS.
  def create_carousel_items(photos)
    raise ArgumentError, "Carousel must contain 2-#{MAX_CAROUSEL_PHOTOS} photos" if photos.size < 2 || photos.size > MAX_CAROUSEL_PHOTOS

    photos.map do |photo|
      create_media_container(
        image_url: photo[:url],
        alt_text: photo[:alt_text],
        is_carousel_item: true
      )
    end
  end

  # Creates the container that holds a carousel's photos, once each of theirs is processed.
  #
  # @param children [Array<String>] the photos' container IDs, from create_carousel_items.
  # @param caption [String] the main caption for the carousel post (max 500 characters).
  # @param topic_tag [String, nil] the topic tag for the post.
  # @param location_id [String, nil] the location ID for the post.
  # @return [String] the carousel container ID.
  # @raise [RuntimeError] if the post request fails.
  def create_carousel_container(children:, caption: '', topic_tag: nil, location_id: nil)
    body = {
      media_type: 'CAROUSEL',
      children: children.join(','),
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

  # Checks how far Meta has got with a container.
  #
  # @param container_id [String] the media container ID to check.
  # @return [Hash] 'code': EXPIRED, ERROR, FINISHED, IN_PROGRESS or PUBLISHED; 'error': what
  #   Meta says went wrong, for an ERROR.
  # @raise [RuntimeError] if the status check fails.
  def container_status(container_id)
    response = HTTParty.get(
      "#{THREADS_API_BASE}/#{container_id}",
      query: {
        fields: 'status,error_message',
        access_token: access_token
      }
    )

    if response.success?
      parsed = JSON.parse(response.body)
      { 'code' => parsed['status'], 'error' => parsed['error_message'] }
    else
      raise_api_error("Failed to check container status", response)
    end
  end

  # Publishes a media container to Threads.
  #
  # @param container_id [String] the media container ID to publish.
  # @return [Hash] the parsed response body, with the new post's media 'id'.
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

  private

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

  # Returns the access token from the social account.
  #
  # @return [String] the access token.
  # @raise [RuntimeError] if no access token is found.
  def access_token
    token = @social_account.access_token&.strip&.presence
    raise "Threads access token not found in social account." if token.blank?
    token
  end

  # Refreshes the token once it's older than TOKEN_REFRESH_THRESHOLD. Threads tokens expire after
  # 60 days, so that leaves weeks to spare.
  #
  # A failed refresh doesn't stop the post: the token still works, and the next post tries again.
  # Once it really has expired, the post itself fails with a MetaAuthError.
  #
  # @return [void]
  def refresh_token_if_needed
    return if @social_account.connected_at.blank?
    return if @social_account.connected_at > TOKEN_REFRESH_THRESHOLD.ago

    refresh_token
  rescue StandardError => e
    Rails.logger.warn("[Threads] Couldn't refresh the token for #{@threads_user_id}; using the current one: #{e.message}")
    Bugsnag.notify(e)
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

