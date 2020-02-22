class SessionsController < ApplicationController
  before_action :block_cloudfront
  before_action :no_cache
  skip_before_action :domain_redirect

  def new
    @page_title = "Sign in · #{@photoblog.name}"
    render
  end

  def create
    auth_hash = request.env['omniauth.auth']

    if auth_hash.present?
      logger.tagged('Auth') { logger.info { "#{auth_hash['info']['name']} (#{auth_hash['info']['email']}) signed in" } }
      flash[:success] = "Welcome back, #{auth_hash['info']['first_name']}!"
      user = User.from_omniauth(auth_hash)
      session[:user_id] = user.id
      url = session[:original_url] || admin_entries_path
      session[:original_url] = nil
      redirect_to url
    else
      flash[:warning] = 'There was a problem signing you in.'
      redirect_to signin_path
    end
  end

  def failure
    logger.tagged('Auth') { logger.warn { "Sign in failure: #{params[:message]}" } }
    flash[:warning] = "There was a problem signing you in: #{params[:message]}."
    redirect_to signin_path
  end

  def destroy
    session[:current_user] = nil
    flash[:success] = 'You have been signed out.'
    redirect_to signin_path
  end
end
