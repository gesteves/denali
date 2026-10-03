class AdminController < ApplicationController
  layout 'admin'
  before_action :block_cdn
  before_action :no_cache
  before_action :require_login
  skip_before_action :domain_redirect
  skip_before_action :preload_assets
  before_action :set_referrer_policy
  helper_method :is_admin?

  # The admin's assets come from its own host, not the public ASSET_HOST. Its
  # JavaScript is a module, and browsers fetch modules with CORS, which the
  # public host doesn't send; loaded from there, none of it runs.
  self.asset_host = nil

  # Report-only for now: violations show up in the browser console without
  # blocking anything. Once the admin runs clean, drop the report_only line.
  # form-action is left out on purpose: Chrome applies it to the redirects after
  # a submit, which would block the OAuth flows that redirect to the providers.
  content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri    :self
    policy.object_src  :none
    policy.frame_ancestors :none
    policy.script_src  :self, 'https://kit.fontawesome.com'
    # Mapbox, Font Awesome and Turbo's progress bar all inject inline styles.
    policy.style_src   :self, :unsafe_inline
    # The kit is a Pro one, so it fetches its CSS and fonts from ka-p (ka-f is
    # the Free CDN's).
    policy.font_src    :self, :data, 'https://ka-p.fontawesome.com'
    # Photos are served from the public domain's image transformations, and the
    # map's tiles from Mapbox.
    policy.img_src     :self, :data, :blob, :https
    policy.connect_src :self, 'https://*.mapbox.com', 'https://ka-p.fontawesome.com'
    policy.worker_src  :self, :blob
  end
  content_security_policy_report_only

  def default_url_options
    if Rails.env.production?
      { host: ENV['DOMAIN_ADMIN'] }
    else
      Rails.application.routes.default_url_options
    end
  end

  def index
    redirect_to admin_entries_path
  end

  def is_admin?
    true
  end

  def set_referrer_policy
    response.headers['Referrer-Policy'] = 'same-origin'
  end
end
