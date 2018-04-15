class SessionsController < ApplicationController
  before_action :block_cloudfront
  before_action :no_cache
  skip_before_action :domain_redirect

  def new
    render
  end

  def create
    auth_hash = request.env['omniauth.auth']

    if auth_hash.present?
      logger.info "#{auth_hash['info']['name']} (#{auth_hash['info']['email']}) signed in"
      flash[:success] = "Welcome, #{auth_hash['info']['name']}!"
      user = User.from_omniauth(auth_hash)
      session[:user_id] = user.id
      url = session[:original_url] || admin_entries_path
      session[:original_url] = nil
      redirect_to url
    else
      redirect_to signin_path, warning: 'There was a problem signing you in.'
    end
  end

  def failure
    redirect_to signin_path, warning: "There was a problem signing you in: #{params[:message]}."
  end

  def destroy
    session[:current_user] = nil
    redirect_to signin_path, success: 'You have been signed out.'
  end
end
