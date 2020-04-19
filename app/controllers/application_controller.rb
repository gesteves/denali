class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :get_photoblog
  before_action :domain_redirect
  before_action :set_referrer_policy
  around_action :set_time_zone

  helper_method :current_user, :logged_in?, :logged_out?, :is_cloudfront?, :is_admin?, :add_preload_link_header, :add_preconnect_link_header

  def default_url_options
    Rails.application.routes.default_url_options
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
    if Rails.env.production? && ENV['aws_cloudfront_distribution_id'].present? && !is_cloudfront?
      protocol = Rails.configuration.force_ssl ? 'https' : 'http'
      redirect_to "#{protocol}://#{Rails.application.routes.default_url_options[:host]}#{request.fullpath}", status: 301
    end
  end

  def no_cache
    expires_now
  end

  def set_max_age(seconds: ENV['CACHE_TTL'].to_i)
    response.headers['Cache-Control'] = "s-maxage=#{seconds}, max-age=0, public"
  end

  def add_preload_link_header(url, opts = {})
    opts.reverse_merge!({ as: 'style' })
    links = [response.headers['Link']]
    link = "<#{url}>; rel=preload; as=#{opts[:as]}"
    link += "; crossorigin=#{opts[:crossorigin]}" if opts[:crossorigin].present?
    link += "; imagesizes=\"#{opts[:imagesizes]}\"" if opts[:imagesizes].present?
    link += "; imagesrcset=\"#{opts[:imagesrcset]}\"" if opts[:imagesrcset].present?
    links << link
    response.headers['Link'] = links.compact.join(', ')
  end

  def add_preconnect_link_header(url, opts = {})
    links = [response.headers['Link']]
    link = "<#{url}>; rel=preconnect"
    link += "; crossorigin=#{opts[:crossorigin]}" if opts[:crossorigin].present?
    links << link
    response.headers['Link'] = links.compact.join(', ')
  end

  def set_referrer_policy
    response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
  end

  def set_time_zone(&block)
    Time.use_zone(@photoblog.time_zone, &block) if @photoblog.present?
  end
end
