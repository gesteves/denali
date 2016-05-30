class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :get_photoblog
  before_action :domain_redirect
  before_action :set_app_version

  helper_method :current_user, :logged_in?, :logged_out?

  def default_url_options
    if Rails.env.production?
      { host: @photoblog.domain }
    else
      {}
    end
  end

  def require_login
    unless current_user
      session[:original_url] = request.original_url
      redirect_to signin_path
    end
  end

  def logged_in?
    current_user.present?
  end

  def logged_out?
    !logged_in?
  end

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end

  def get_photoblog
    @photoblog = Blog.first
  end

  def domain_redirect
    # Prevent people from bypassing CloudFront and hitting Heroku directly,
    # by checking the `X-Denali-Secret` header, which should be sent by CloudFront.
    # If it doesn't match the secret in the environment variables,
    # redirect the visitor to the CDN.
    if Rails.env.production? && !request.host.try(:match, @photoblog.domain) && request.headers['X-Denali-Secret'] != ENV['denali_secret']
      protocol = Rails.configuration.force_ssl ? 'https' : 'http'
      redirect_to "#{protocol}://#{@photoblog.domain}#{request.fullpath}", status: 301
    end
  end

  def set_max_age
    max_age = @photoblog.max_age
    expires_in max_age.minutes, :public => true
  end

  def no_cache
    expires_in 0, must_revalidate: true
  end

  def block_cloudfront
    if request.user_agent.try(:match, /cloudfront/i)
      raise ActionController::RoutingError.new('Not Found')
    end
  end

  def check_if_user_has_visited
    @has_visited = cookies[:has_visited].present?
    cookies[:has_visited] = { value: true, expires: 1.year.from_now }
  end

  def set_app_version
    # Requires enabling dyno metadata with `heroku labs:enable runtime-dyno-metadata`
    # See: https://devcenter.heroku.com/articles/dyno-metadata
    @app_version = ENV['HEROKU_RELEASE_VERSION'] || 'v1'
  end
end
