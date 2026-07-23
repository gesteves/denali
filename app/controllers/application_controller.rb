class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :set_photoblog
  before_action :domain_redirect
  before_action :set_referrer_policy
  before_action :preload_assets
  around_action :set_time_zone

  helper_method :current_user, :logged_in?, :logged_out?, :behind_cdn?, :is_admin?

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

  def behind_cdn?
    request.headers['X-Denali-Secret'] == ENV['DENALI_SECRET']
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def set_photoblog
    @photoblog = Blog.first
  end

  def block_cdn
    if Rails.env.production? && behind_cdn?
      raise ActionController::RoutingError.new('Not Found')
    end
  end

  def domain_redirect
    # Prevent people from bypassing the CDN and hitting the app server directly.
    if Rails.env.production? && ENV['CDN_ORIGIN_PROTECTION'].present? && !behind_cdn?
      protocol = Rails.configuration.force_ssl ? 'https' : 'http'
      http_cache_forever(public: true) do
        redirect_to "#{protocol}://#{Rails.application.routes.default_url_options[:host]}#{request.fullpath}", status: 301
      end
    end
  end

  # Admin, session and health responses must never be written to disk by a
  # browser or an intermediary, so no-store rather than expires_now's no-cache.
  def no_cache
    no_store
  end

  # Browsers always revalidate (max-age=0), so a purge is never defeated by a
  # stale copy we can't reach. Cloudflare holds the response until CachePurgeJob
  # purges one of its tags; CACHE_TTL is only the backstop for a missed purge.
  #
  # The edge directives go in Cloudflare-CDN-Cache-Control rather than s-maxage,
  # which implies proxy-revalidate (RFC 9111 §4.2.4) and so would disable both
  # stale directives below. Cloudflare consumes this header and strips it before
  # the response reaches a client.
  #
  # Serving stale doesn't undermine purging: a purge deletes the entry outright,
  # so a purged page is a true MISS. The stale window only ever covers a lapsed
  # TTL — nobody waits on a re-render — and an origin failure, which is what
  # keeps the site up through a Fly outage or a bad deploy.
  def set_max_age(seconds: ENV.fetch('CACHE_TTL', 1.day.to_i), stale: 1.week.to_i)
    expires_in 0.seconds, public: true
    response.headers['Cloudflare-CDN-Cache-Control'] =
      "public, max-age=#{seconds.to_i}, stale-while-revalidate=#{stale.to_i}, stale-if-error=#{stale.to_i}"
  end

  # Cloudflare consumes and strips this header. Purging a tag invalidates every
  # cached response carrying it; see app/jobs/cache_purge_job.rb for the
  # vocabulary and who purges what.
  def set_cache_tags(*tags)
    response.headers['Cache-Tag'] = tags.flatten.compact.uniq.join(',')
  end

  def set_referrer_policy
    response.headers['Referrer-Policy'] = 'no-referrer-when-downgrade'
  end

  def set_time_zone(&block)
    Time.use_zone(@photoblog.time_zone, &block) if @photoblog.present?
  end

  def add_preload_link_header(url, opts = {})
    opts.reverse_merge!({ as: 'style' })
    links = [response.headers['Link']]
    link = "<#{url}>; rel=preload; as=#{opts[:as]}"
    link += "; type=\"#{opts[:type]}\"" if opts[:type].present?
    link += "; crossorigin" if opts[:crossorigin].present?
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

  def preload_assets
    if request.format.html?
      add_preload_link_header(ActionController::Base.helpers.stylesheet_path('application'), as: 'style')
      add_preload_link_header(ActionController::Base.helpers.javascript_path('application'), as: 'script')
      add_preload_link_header(ActionController::Base.helpers.font_path('lato-v25-latin-300.woff2'), as: 'font', type: 'font/woff2', crossorigin: true)
      add_preload_link_header(ActionController::Base.helpers.font_path('lato-v25-latin-300italic.woff2'), as: 'font', type: 'font/woff2', crossorigin: true)
      add_preload_link_header(ActionController::Base.helpers.font_path('lato-v25-latin-regular.woff2'), as: 'font', type: 'font/woff2', crossorigin: true)
      add_preload_link_header(ActionController::Base.helpers.font_path('lato-v25-latin-italic.woff2'), as: 'font', type: 'font/woff2', crossorigin: true)
      add_preload_link_header(ActionController::Base.helpers.font_path('lato-v25-latin-700.woff2'), as: 'font', type: 'font/woff2', crossorigin: true)
      add_preload_link_header(ActionController::Base.helpers.font_path('lato-v25-latin-700italic.woff2'), as: 'font', type: 'font/woff2', crossorigin: true)
    end
  end
end
