class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :get_photoblog
  before_action :domain_redirect

  helper_method :current_user, :logged_in?, :logged_out?, :permalink_path, :permalink_url, :short_permalink_url

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
    @photoblog = Blog.find_by(domain: 'www.allencompassingtrip.com')
  end

  def permalink_path(entry, opts = {})
    year, month, day, id, slug = entry.slug_params
    entry_long_path(year, month, day, id, slug)
  end

  def permalink_url(entry)
    year, month, day, id, slug = entry.slug_params
    entry_long_url(year, month, day, id, slug)
  end

  def short_permalink_url(entry)
    entry_url(entry.id, { host: @photoblog.short_domain })
  end

  def domain_redirect
    if Rails.env.production? && !request.host.try(:match, @photoblog.domain) && !request.user_agent.try(:match, /cloudfront/i)
      protocol = Rails.configuration.force_ssl ? 'https' : 'http'
      redirect_to "#{protocol}://#{@photoblog.domain}#{request.fullpath}", status: 301
    end
  end

  def set_max_age
    max_age = ENV['default_max_age'].try(:to_i) || 60
    expires_in max_age.minutes, :public => true
  end

  def no_cache
    expires_in 0, private: true, must_revalidate: true
  end

  def block_cloudfront
    if request.user_agent.try(:match, /cloudfront/i)
      raise ActionController::RoutingError.new('Not Found')
    end
  end
end
