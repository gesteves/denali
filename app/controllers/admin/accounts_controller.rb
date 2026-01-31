class Admin::AccountsController < AdminController
  def index
    @bluesky_account = current_user.bluesky_account
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
      format.html { redirect_to admin_accounts_path, notice: "Bluesky account connected!" }
    end
  rescue => e
    error_message = friendly_bluesky_error(e)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("bluesky-section", partial: "admin/accounts/bluesky_section", locals: { social_account: @social_account, error: error_message }) }
      format.html { redirect_to admin_accounts_path, alert: error_message }
    end
  end

  def destroy_bluesky
    @social_account = current_user.bluesky_account
    @social_account&.destroy

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("bluesky-section", partial: "admin/accounts/bluesky_section", locals: { social_account: nil, error: nil }) }
      format.html { redirect_to admin_accounts_path, notice: "Bluesky account disconnected." }
    end
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
end
