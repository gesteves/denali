class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  helper_method :current_user, :logged_in?, :logged_out?, :photoblog, :permalink

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

  def photoblog
    Blog.find_by(domain: 'www.allencompassingtrip.com')
  end

  def permalink(entry, opts = {})
    opts.reverse_merge! path_only: true
    if entry.is_published?
      entry_date = entry.published_at
      year = entry_date.strftime('%Y')
      month = entry_date.strftime('%-m')
      day = entry_date.strftime('%-d')
      id = entry.id
      slug = entry.slug

      if opts[:path_only]
        entry_long_path(year, month, day, id, slug)
      else
        entry_long_url(year, month, day, id, slug)
      end
    else
      ''
    end
  end
end
