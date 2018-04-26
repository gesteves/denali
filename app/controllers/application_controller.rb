class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :get_photoblog
  before_action :domain_redirect
  before_action :set_app_version

  helper_method :current_user, :logged_in?, :logged_out?, :is_cloudfront?, :is_admin?

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

  def is_admin?
    false
  end

  def is_cloudfront?
    request.headers['X-Denali-Secret'] == ENV['denali_secret']
  end

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end

  def get_photoblog
    @photoblog = Blog.first
  end

  def block_cloudfront
    if Rails.env.production? && is_cloudfront?
      raise ActionController::RoutingError.new('Not Found')
    end
  end

  def domain_redirect
    # Prevent people from bypassing CloudFront and hitting Heroku directly.
    if Rails.env.production? && !is_cloudfront?
      protocol = Rails.configuration.force_ssl ? 'https' : 'http'
      redirect_to "#{protocol}://#{@photoblog.domain}#{request.fullpath}", status: 301
    end
  end

  def no_cache
    expires_now
  end

  def set_max_age
    max_age = ENV['config_caching_minutes']&.to_i || 5
    expires_in max_age.minutes, public: true
  end

  def set_entry_max_age
    max_age = ENV['config_entry_caching_minutes']&.to_i || ENV['config_caching_minutes']&.to_i || 5
    expires_in max_age.minutes, public: true
  end

  def set_app_version
    # Requires enabling dyno metadata with `heroku labs:enable runtime-dyno-metadata`
    # See: https://devcenter.heroku.com/articles/dyno-metadata
    @app_version = ENV['HEROKU_RELEASE_VERSION'] || 'v1'
  end

  def check_if_user_has_visited
    @has_visited = cookies[:has_visited] == @app_version
    cookies[:has_visited] = { value: @app_version, expires: 1.month.from_now }
  end
end
