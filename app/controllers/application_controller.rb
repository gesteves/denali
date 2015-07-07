class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :get_photoblog

  helper_method :current_user, :logged_in?, :logged_out?, :permalink_path, :permalink_url, :short_permalink_url

  def default_url_options
    if Rails.env.production?
      { host: @photoblog.domain }
    else
      {}
    end
  end

  def require_login
    redirect_to signin_path unless current_user
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
    if Rails.env.production? && !request.host.match(@photoblog.domain) && !request.user_agent.match(/cloudfront/i)
      redirect_to "http://#{@photoblog.domain}#{request.fullpath}", status: 301
    end
  end
end
