class Admin::AccountsController < AdminController
  skip_before_action :require_login, only: [:instagram_deauthorize, :instagram_delete, :instagram_deletion_status, :threads_deauthorize, :threads_delete, :threads_deletion_status]
  skip_forgery_protection only: [:instagram_deauthorize, :instagram_delete, :threads_deauthorize, :threads_delete]

  def index
    @bluesky_account = current_user.bluesky_account
    @flickr_account = current_user.flickr_account
    @instagram_account = current_user.instagram_account
    @mastodon_account = current_user.mastodon_account
    @threads_account = current_user.threads_account
  end

  def create_bluesky
    @social_account = current_user.social_accounts.find_or_initialize_by(provider: 'bluesky')
    @social_account.assign_attributes(bluesky_params)
    @social_account.connected_at = Time.current

    # Run validations to normalize the handle (removes leading @)
    @social_account.validate

    bluesky = Bluesky.new(
      base_url: @social_account.server_url,
      email: @social_account.handle,
      password: @social_account.access_token
    )
    @social_account.uid = bluesky.send(:did)
    @social_account.save!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to admin_accounts_path, flash: { success: "Bluesky account connected!" } }
    end
  rescue => e
    error_message = friendly_bluesky_error(e)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("bluesky-card", partial: "admin/accounts/bluesky_card", locals: { social_account: @social_account, error: error_message }) }
      format.html { redirect_to admin_accounts_path, flash: { danger: error_message } }
    end
  end

  def destroy_bluesky
    @social_account = current_user.bluesky_account
    @social_account&.destroy

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("bluesky-card", partial: "admin/accounts/bluesky_card", locals: { social_account: nil, error: nil }) }
      format.html { redirect_to admin_accounts_path, flash: { success: "Bluesky account disconnected." } }
    end
  end

  def initiate_flickr
    if ENV['FLICKR_CONSUMER_KEY'].blank? || ENV['FLICKR_CONSUMER_SECRET'].blank?
      redirect_to admin_accounts_path, flash: { danger: "Flickr API credentials are not configured." }
      return
    end

    flickr = FlickRaw::Flickr.new(ENV['FLICKR_CONSUMER_KEY'], ENV['FLICKR_CONSUMER_SECRET'])
    token = flickr.get_request_token(oauth_callback: flickr_callback_url)

    session[:flickr_oauth_token] = token['oauth_token']
    session[:flickr_oauth_token_secret] = token['oauth_token_secret']

    auth_url = flickr.get_authorize_url(token['oauth_token'], perms: 'delete')
    redirect_to auth_url, allow_other_host: true
  rescue => e
    Rails.logger.error("[Flickr] OAuth initiation error: #{e.message}")
    cleanup_flickr_session
    redirect_to admin_accounts_path, flash: { danger: friendly_flickr_error(e) }
  end

  def flickr_callback
    if params[:oauth_token] != session[:flickr_oauth_token]
      cleanup_flickr_session
      redirect_to admin_accounts_path, flash: { danger: "Invalid OAuth token. Please try again." }
      return
    end

    flickr = FlickRaw::Flickr.new(ENV['FLICKR_CONSUMER_KEY'], ENV['FLICKR_CONSUMER_SECRET'])
    access = flickr.get_access_token(
      session[:flickr_oauth_token],
      session[:flickr_oauth_token_secret],
      params[:oauth_verifier]
    )

    flickr.access_token = access['oauth_token']
    flickr.access_secret = access['oauth_token_secret']

    login = flickr.test.login

    @social_account = current_user.social_accounts.find_or_initialize_by(provider: 'flickr')
    @social_account.assign_attributes(
      handle: login.username,
      uid: login.id,
      access_token: access['oauth_token'],
      access_token_secret: access['oauth_token_secret'],
      connected_at: Time.current
    )
    @social_account.save!

    cleanup_flickr_session
    redirect_to admin_accounts_path, flash: { success: "Flickr account connected successfully!" }
  rescue => e
    Rails.logger.error("[Flickr] Callback error: #{e.message}")
    cleanup_flickr_session
    redirect_to admin_accounts_path, flash: { danger: friendly_flickr_error(e) }
  end

  def destroy_flickr
    @social_account = current_user.flickr_account
    @social_account&.destroy

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("flickr-card", partial: "admin/accounts/flickr_card", locals: { social_account: nil, error: nil }) }
      format.html { redirect_to admin_accounts_path, flash: { success: "Flickr account disconnected." } }
    end
  end

  def initiate_instagram
    if ENV['INSTAGRAM_APP_ID'].blank? || ENV['INSTAGRAM_APP_SECRET'].blank?
      redirect_to admin_accounts_path, flash: { danger: "Instagram API credentials are not configured." }
      return
    end

    state = SecureRandom.hex(32)
    session[:instagram_oauth_state] = state

    scopes = 'instagram_business_basic,instagram_business_content_publish'
    authorize_url = "https://www.instagram.com/oauth/authorize?" + {
      client_id: ENV['INSTAGRAM_APP_ID'],
      redirect_uri: instagram_callback_url,
      response_type: 'code',
      scope: scopes,
      state: state
    }.to_query

    redirect_to authorize_url, allow_other_host: true
  end

  def instagram_callback
    if params[:state] != session[:instagram_oauth_state]
      redirect_to admin_accounts_path, flash: { danger: "Invalid OAuth state. Please try again." }
      return
    end

    if params[:error].present?
      redirect_to admin_accounts_path, flash: { danger: "Authorization was denied: #{params[:error_description] || params[:error]}" }
      return
    end

    # Step 1: Exchange code for short-lived token
    token_response = HTTParty.post("https://api.instagram.com/oauth/access_token", body: {
      client_id: ENV['INSTAGRAM_APP_ID'],
      client_secret: ENV['INSTAGRAM_APP_SECRET'],
      grant_type: 'authorization_code',
      redirect_uri: instagram_callback_url,
      code: params[:code]
    })

    unless token_response.code == 200
      Rails.logger.error("[Instagram] Token exchange failed: #{token_response.body}")
      redirect_to admin_accounts_path, flash: { danger: "Failed to get access token. Please try again." }
      return
    end

    token_data = JSON.parse(token_response.body)
    short_lived_token = token_data['access_token']
    user_id = token_data['user_id']

    # Step 2: Exchange for long-lived token
    long_lived_response = HTTParty.get("https://graph.instagram.com/access_token", query: {
      grant_type: 'ig_exchange_token',
      client_secret: ENV['INSTAGRAM_APP_SECRET'],
      access_token: short_lived_token
    })

    unless long_lived_response.code == 200
      Rails.logger.error("[Instagram] Long-lived token exchange failed: #{long_lived_response.body}")
      redirect_to admin_accounts_path, flash: { danger: "Failed to get long-lived token. Please try again." }
      return
    end

    long_lived_data = JSON.parse(long_lived_response.body)
    access_token = long_lived_data['access_token']

    # Step 3: Get user info (username)
    user_response = HTTParty.get("https://graph.instagram.com/me", query: {
      fields: 'user_id,username',
      access_token: access_token
    })
    user_info = user_response.code == 200 ? JSON.parse(user_response.body) : {}

    # Step 4: Save to database
    @social_account = current_user.social_accounts.find_or_initialize_by(provider: 'instagram')
    @social_account.assign_attributes(
      uid: user_id.to_s,
      handle: user_info['username'],
      access_token: access_token,
      connected_at: Time.current
    )
    @social_account.save!

    cleanup_instagram_session
    redirect_to admin_accounts_path, flash: { success: "Instagram account connected successfully!" }
  rescue => e
    Rails.logger.error("[Instagram] Callback error: #{e.message}")
    cleanup_instagram_session
    redirect_to admin_accounts_path, flash: { danger: friendly_instagram_error(e) }
  end

  def destroy_instagram
    @social_account = current_user.instagram_account
    @social_account&.destroy

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("instagram-card", partial: "admin/accounts/instagram_card", locals: { social_account: nil, error: nil }) }
      format.html { redirect_to admin_accounts_path, flash: { success: "Instagram account disconnected." } }
    end
  end

  def initiate_mastodon
    instance_url = params[:instance_url].to_s.strip
    if instance_url.blank?
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("mastodon-card", partial: "admin/accounts/mastodon_card", locals: { social_account: nil, error: "Please enter your Mastodon instance URL." }) }
        format.html { redirect_to admin_accounts_path, flash: { danger: "Please enter your Mastodon instance URL." } }
      end
      return
    end

    mastodon_app = MastodonApp.for_instance(instance_url)

    # Store state for CSRF protection
    state = SecureRandom.hex(32)
    session[:mastodon_oauth_state] = state
    session[:mastodon_instance_url] = mastodon_app.instance_url

    authorize_url = "#{mastodon_app.instance_url}/oauth/authorize?" + {
      client_id: mastodon_app.client_id,
      redirect_uri: MastodonApp.redirect_uri,
      response_type: 'code',
      scope: 'read write:media write:statuses',
      state: state
    }.to_query

    redirect_to authorize_url, allow_other_host: true
  rescue => e
    error_message = friendly_mastodon_error(e)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("mastodon-card", partial: "admin/accounts/mastodon_card", locals: { social_account: nil, error: error_message }) }
      format.html { redirect_to admin_accounts_path, flash: { danger: error_message } }
    end
  end

  def mastodon_callback
    # Verify state parameter
    if params[:state] != session[:mastodon_oauth_state]
      redirect_to admin_accounts_path, flash: { danger: "Invalid OAuth state. Please try again." }
      return
    end

    if params[:error].present?
      redirect_to admin_accounts_path, flash: { danger: "Authorization was denied: #{params[:error_description] || params[:error]}" }
      return
    end

    instance_url = session[:mastodon_instance_url]
    mastodon_app = MastodonApp.find_by!(instance_url: instance_url)

    # Exchange code for access token
    token_response = HTTParty.post("#{instance_url}/oauth/token", body: {
      client_id: mastodon_app.client_id,
      client_secret: mastodon_app.client_secret,
      redirect_uri: MastodonApp.redirect_uri,
      grant_type: 'authorization_code',
      code: params[:code],
      scope: 'read write:media write:statuses'
    })

    unless token_response.code == 200
      Rails.logger.error("[Mastodon] Token exchange failed: #{token_response.body}")
      redirect_to admin_accounts_path, flash: { danger: "Failed to complete authorization. Please try again." }
      return
    end

    token_data = JSON.parse(token_response.body)
    access_token = token_data['access_token']

    # Fetch user info
    user_response = HTTParty.get("#{instance_url}/api/v1/accounts/verify_credentials", headers: {
      'Authorization' => "Bearer #{access_token}"
    })

    unless user_response.code == 200
      Rails.logger.error("[Mastodon] Failed to fetch user info: #{user_response.body}")
      redirect_to admin_accounts_path, flash: { danger: "Failed to fetch account information. Please try again." }
      return
    end

    user_data = JSON.parse(user_response.body)

    # Create or update the social account
    @social_account = current_user.social_accounts.find_or_initialize_by(provider: 'mastodon')
    @social_account.assign_attributes(
      handle: user_data['acct'],
      uid: user_data['id'],
      access_token: access_token,
      server_url: instance_url,
      connected_at: Time.current
    )
    @social_account.save!

    # Clean up session
    session.delete(:mastodon_oauth_state)
    session.delete(:mastodon_instance_url)

    redirect_to admin_accounts_path, flash: { success: "Mastodon account connected successfully!" }
  rescue => e
    Rails.logger.error("[Mastodon] Callback error: #{e.message}")
    session.delete(:mastodon_oauth_state)
    session.delete(:mastodon_instance_url)
    redirect_to admin_accounts_path, flash: { danger: "Failed to connect Mastodon account. Please try again." }
  end

  def destroy_mastodon
    @social_account = current_user.mastodon_account
    @social_account&.destroy

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("mastodon-card", partial: "admin/accounts/mastodon_card", locals: { social_account: nil, error: nil }) }
      format.html { redirect_to admin_accounts_path, flash: { success: "Mastodon account disconnected." } }
    end
  end

  def initiate_threads
    if ENV['THREADS_APP_ID'].blank? || ENV['THREADS_APP_SECRET'].blank?
      redirect_to admin_accounts_path, flash: { danger: "Threads API credentials are not configured." }
      return
    end

    state = SecureRandom.hex(32)
    session[:threads_oauth_state] = state

    scopes = 'threads_basic,threads_content_publish,threads_location_tagging'
    authorize_url = "https://threads.net/oauth/authorize?" + {
      client_id: ENV['THREADS_APP_ID'],
      redirect_uri: threads_callback_url,
      response_type: 'code',
      scope: scopes,
      state: state
    }.to_query

    redirect_to authorize_url, allow_other_host: true
  end

  def threads_callback
    if params[:state] != session[:threads_oauth_state]
      redirect_to admin_accounts_path, flash: { danger: "Invalid OAuth state. Please try again." }
      return
    end

    if params[:error].present?
      redirect_to admin_accounts_path, flash: { danger: "Authorization was denied: #{params[:error_description] || params[:error]}" }
      return
    end

    # Step 1: Exchange code for short-lived token (POST request)
    token_response = HTTParty.post("https://graph.threads.net/oauth/access_token", body: {
      client_id: ENV['THREADS_APP_ID'],
      client_secret: ENV['THREADS_APP_SECRET'],
      grant_type: 'authorization_code',
      redirect_uri: threads_callback_url,
      code: params[:code]
    })

    unless token_response.code == 200
      Rails.logger.error("[Threads] Token exchange failed: #{token_response.body}")
      redirect_to admin_accounts_path, flash: { danger: "Failed to get access token. Please try again." }
      return
    end

    token_data = JSON.parse(token_response.body)
    short_lived_token = token_data['access_token']
    user_id = token_data['user_id']

    # Step 2: Exchange for long-lived token (GET request with th_exchange_token)
    long_lived_response = HTTParty.get("https://graph.threads.net/access_token", query: {
      grant_type: 'th_exchange_token',
      client_secret: ENV['THREADS_APP_SECRET'],
      access_token: short_lived_token
    })

    unless long_lived_response.code == 200
      Rails.logger.error("[Threads] Long-lived token exchange failed: #{long_lived_response.body}")
      redirect_to admin_accounts_path, flash: { danger: "Failed to get long-lived token. Please try again." }
      return
    end

    long_lived_data = JSON.parse(long_lived_response.body)
    access_token = long_lived_data['access_token']

    # Step 3: Get user info (username)
    user_response = HTTParty.get("https://graph.threads.net/v1.0/me", query: {
      fields: 'id,username',
      access_token: access_token
    })
    user_info = user_response.code == 200 ? JSON.parse(user_response.body) : {}

    # Step 4: Save to database
    @social_account = current_user.social_accounts.find_or_initialize_by(provider: 'threads')
    @social_account.assign_attributes(
      uid: user_id.to_s,
      handle: user_info['username'],
      access_token: access_token,
      connected_at: Time.current
    )
    @social_account.save!

    cleanup_threads_session
    redirect_to admin_accounts_path, flash: { success: "Threads account connected successfully!" }
  rescue => e
    Rails.logger.error("[Threads] Callback error: #{e.message}")
    cleanup_threads_session
    redirect_to admin_accounts_path, flash: { danger: friendly_threads_error(e) }
  end

  def destroy_threads
    @social_account = current_user.threads_account
    @social_account&.destroy

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("threads-card", partial: "admin/accounts/threads_card", locals: { social_account: nil, error: nil }) }
      format.html { redirect_to admin_accounts_path, flash: { success: "Threads account disconnected." } }
    end
  end

  # Instagram webhook: called when user removes app from Instagram settings
  def instagram_deauthorize
    user_id = parse_signed_request(params[:signed_request], ENV['INSTAGRAM_APP_SECRET'])
    if user_id
      account = SocialAccount.find_by(provider: 'instagram', uid: user_id.to_s)
      account&.destroy
      Rails.logger.info("[Instagram] Deauthorized user #{user_id}")
    end
    head :ok
  rescue => e
    Rails.logger.error("[Instagram] Deauthorize error: #{e.message}")
    head :ok
  end

  # Instagram webhook: called when user requests data deletion
  def instagram_delete
    user_id = parse_signed_request(params[:signed_request], ENV['INSTAGRAM_APP_SECRET'])
    if user_id
      account = SocialAccount.find_by(provider: 'instagram', uid: user_id.to_s)
      account&.destroy
      Rails.logger.info("[Instagram] Deleted data for user #{user_id}")

      confirmation_code = SecureRandom.hex(16)
      render json: {
        url: instagram_deletion_status_admin_accounts_url(code: confirmation_code),
        confirmation_code: confirmation_code
      }
    else
      head :bad_request
    end
  rescue => e
    Rails.logger.error("[Instagram] Delete error: #{e.message}")
    head :bad_request
  end

  # Instagram: status page for data deletion confirmation
  def instagram_deletion_status
    render plain: "Data deletion request confirmed. Confirmation code: #{params[:code]}"
  end

  # Threads webhook: called when user removes app from Threads settings
  def threads_deauthorize
    user_id = parse_signed_request(params[:signed_request], ENV['THREADS_APP_SECRET'])
    if user_id
      account = SocialAccount.find_by(provider: 'threads', uid: user_id.to_s)
      account&.destroy
      Rails.logger.info("[Threads] Deauthorized user #{user_id}")
    end
    head :ok
  rescue => e
    Rails.logger.error("[Threads] Deauthorize error: #{e.message}")
    head :ok
  end

  # Threads webhook: called when user requests data deletion
  def threads_delete
    user_id = parse_signed_request(params[:signed_request], ENV['THREADS_APP_SECRET'])
    if user_id
      account = SocialAccount.find_by(provider: 'threads', uid: user_id.to_s)
      account&.destroy
      Rails.logger.info("[Threads] Deleted data for user #{user_id}")

      confirmation_code = SecureRandom.hex(16)
      render json: {
        url: threads_deletion_status_admin_accounts_url(code: confirmation_code),
        confirmation_code: confirmation_code
      }
    else
      head :bad_request
    end
  rescue => e
    Rails.logger.error("[Threads] Delete error: #{e.message}")
    head :bad_request
  end

  # Threads: status page for data deletion confirmation
  def threads_deletion_status
    render plain: "Data deletion request confirmed. Confirmation code: #{params[:code]}"
  end

  private

  def bluesky_params
    params.require(:social_account).permit(:handle, :access_token, :server_url)
  end

  def friendly_bluesky_error(exception)
    case exception.message
    when /Unable to create a new session/i
      "Could not connect to Bluesky. Please check your handle and app password are correct."
    when /getaddrinfo|connection refused|network|timeout/i
      "Could not reach the Bluesky server. Please check the server URL and try again."
    when /Invalid identifier or password/i
      "Invalid handle or app password. Please check your credentials and try again."
    else
      "Could not connect to Bluesky: #{exception.message}"
    end
  end

  def friendly_mastodon_error(exception)
    case exception.message
    when /getaddrinfo|connection refused|network|timeout/i
      "Could not reach the Mastodon instance. Please check the URL and try again."
    when /Failed to register app/i
      "Could not register with this Mastodon instance. Please check the URL and try again."
    else
      "Could not connect to Mastodon: #{exception.message}"
    end
  end

  def cleanup_flickr_session
    session.delete(:flickr_oauth_token)
    session.delete(:flickr_oauth_token_secret)
  end

  def friendly_flickr_error(exception)
    case exception.message
    when /getaddrinfo|connection refused|network|timeout/i
      "Could not reach Flickr. Please try again later."
    when /Invalid.*token|oauth.*invalid/i
      "Authorization failed. Please try again."
    else
      "Could not connect to Flickr: #{exception.message}"
    end
  end

  def flickr_callback_url
    if Rails.env.production? && ENV['DOMAIN_ADMIN'].present?
      "https://#{ENV['DOMAIN_ADMIN']}/admin/accounts/flickr/callback"
    else
      flickr_callback_admin_accounts_url
    end
  end

  def cleanup_instagram_session
    session.delete(:instagram_oauth_state)
  end

  def friendly_instagram_error(exception)
    case exception.message
    when /access_denied|user_denied/i
      "Authorization was denied."
    when /Invalid.*code|code.*expired/i
      "Authorization code expired. Please try again."
    else
      "Could not connect to Instagram: #{exception.message}"
    end
  end

  def instagram_callback_url
    if Rails.env.production? && ENV['DOMAIN_ADMIN'].present?
      "https://#{ENV['DOMAIN_ADMIN']}/admin/accounts/instagram/callback"
    else
      instagram_callback_admin_accounts_url
    end
  end

  def cleanup_threads_session
    session.delete(:threads_oauth_state)
  end

  def friendly_threads_error(exception)
    case exception.message
    when /access_denied|user_denied/i
      "Authorization was denied."
    when /Invalid.*code|code.*expired/i
      "Authorization code expired. Please try again."
    else
      "Could not connect to Threads: #{exception.message}"
    end
  end

  def threads_callback_url
    if Rails.env.production? && ENV['DOMAIN_ADMIN'].present?
      "https://#{ENV['DOMAIN_ADMIN']}/admin/accounts/threads/callback"
    else
      threads_callback_admin_accounts_url
    end
  end

  # Parses Meta's signed request format used in deauthorize/delete webhooks
  # Format: {base64url_signature}.{base64url_payload}
  # Returns user_id if valid, nil otherwise
  def parse_signed_request(signed_request, app_secret)
    return nil if signed_request.blank? || app_secret.blank?

    encoded_sig, payload = signed_request.split('.', 2)
    return nil if encoded_sig.blank? || payload.blank?

    # Decode signature and payload (base64url encoding)
    signature = base64_url_decode(encoded_sig)
    data = JSON.parse(base64_url_decode(payload))

    # Verify algorithm
    return nil unless data['algorithm']&.upcase == 'HMAC-SHA256'

    # Verify signature
    expected_sig = OpenSSL::HMAC.digest('SHA256', app_secret, payload)
    return nil unless ActiveSupport::SecurityUtils.secure_compare(signature, expected_sig)

    data['user_id']
  rescue JSON::ParserError, ArgumentError => e
    Rails.logger.error("[Meta] Failed to parse signed request: #{e.message}")
    nil
  end

  def base64_url_decode(str)
    # Convert base64url to base64 and decode
    str = str.tr('-_', '+/')
    str += '=' * (4 - str.length % 4) if str.length % 4 != 0
    Base64.decode64(str)
  end
end
