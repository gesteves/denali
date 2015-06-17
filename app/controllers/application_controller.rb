class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  before_filter :get_photoblog

  helper_method :current_user, :logged_in?, :logged_out?, :permalink_path, :permalink_url

  def default_url_options
    if Rails.env.production?
      { host: @photoblog.domain }
    else
      {}
    end
  end

  def require_login
    redirect_to signin_url unless current_user
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
    opts.reverse_merge! path_only: true
    if entry.is_published?
      entry_date = entry.published_at
      year = entry_date.strftime('%Y')
      month = entry_date.strftime('%-m')
      day = entry_date.strftime('%-d')
      id = entry.id
      slug = entry.slug
      entry_long_path(year, month, day, id, slug)
    else
      ''
    end
  end

  def permalink_url(entry, opts = {})
    opts.reverse_merge! path_only: true
    if entry.is_published?
      entry_date = entry.published_at
      year = entry_date.strftime('%Y')
      month = entry_date.strftime('%-m')
      day = entry_date.strftime('%-d')
      id = entry.id
      slug = entry.slug
      entry_long_url(year, month, day, id, slug)
    else
      ''
    end
  end

  def domain_redirect
    if Rails.env.production? && !request.host.match(@photoblog.domain) && !request.user_agent.match(/cloudfront/i)
      redirect_to "http://#{@photoblog.domain}#{request.fullpath}", status: 301
    end
  end
end
