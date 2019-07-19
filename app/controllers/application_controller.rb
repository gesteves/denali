class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :get_photoblog
  before_action :domain_redirect
  before_action :set_app_version
  before_action :set_link_headers
  before_action :set_referrer_policy
  before_action :is_repeat_visit?
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

  def set_max_age
    @max_age = ENV['config_caching_minutes']&.to_i || 5
    response.headers['Cache-Control'] = "s-maxage=#{@max_age.minutes}, max-age=0, public"
  end

  def set_entry_max_age
    @max_age = ENV['config_entry_caching_minutes']&.to_i || ENV['config_caching_minutes']&.to_i || 5
    response.headers['Cache-Control'] = "s-maxage=#{@max_age.minutes}, max-age=0, public"
  end

  def set_app_version
    # Requires enabling dyno metadata with `heroku labs:enable runtime-dyno-metadata`
    # See: https://devcenter.heroku.com/articles/dyno-metadata
    @app_version = ENV['HEROKU_RELEASE_VERSION'] || 'v1'
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

  def set_link_headers
    if request.format.html?
      ENV['imgix_domain'].split(',').each do |domain|
        add_preconnect_link_header("http#{'s' if ENV['imgix_secure'].present?}://#{domain}")
      end
    end
  end

  def set_referrer_policy
    response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
  end

  def set_time_zone(&block)
    Time.use_zone(@photoblog.time_zone, &block)
  end

  def is_repeat_visit?
    @has_visited = cookies[:has_visited] == @app_version
    cookies[:has_visited] = { value: @app_version, expires: 1.month.from_now }
  end
end
