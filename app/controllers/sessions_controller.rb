class SessionsController < ApplicationController
  before_action :block_cdn
  before_action :no_cache
  skip_before_action :domain_redirect

  def new
    @page_title = "Sign in – #{@photoblog.name}"
    render
  end

  def create
    auth_hash = request.env['omniauth.auth']

    if auth_hash.present?
      user = User.find_by(email: auth_hash['info']['email'])

      if user
        logger.tagged('Auth') { logger.info { "#{auth_hash['info']['name']} (#{auth_hash['info']['email']}) signed in" } }
        user.update!(
          name: auth_hash['info']['name'],
          first_name: auth_hash['info']['first_name'],
          last_name: auth_hash['info']['last_name'],
          avatar_url: auth_hash['info']['image']
        )
        url = session[:original_url] || admin_entries_path
        # A fresh session ID on sign-in, so one planted before it (session
        # fixation) never becomes an authenticated session.
        reset_session
        session[:user_id] = user.id
        flash[:success] = "Welcome back, #{user.first_name}!"
        redirect_to url
      else
        logger.tagged('Auth') { logger.warn { "Rejected sign-in from unknown email: #{auth_hash['info']['email']}" } }
        flash[:warning] = 'Your account is not authorized to sign in.'
        redirect_to signin_path
      end
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
    logger.tagged('Auth') { logger.info { "User #{current_user&.name} (#{current_user&.email}) signed out" } }
    reset_session
    flash[:success] = 'You have been signed out.'
    redirect_to signin_path
  end
end
