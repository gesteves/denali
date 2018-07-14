class AdminController < ApplicationController
  layout 'admin'
  before_action :block_cloudfront
  before_action :no_cache
  before_action :require_login
  skip_before_action :domain_redirect
  helper_method :is_admin?

  def index
    redirect_to admin_entries_path
  end

  def is_admin?
    true
  end

  def set_link_headers
    if request.format.html?
      add_preload_link_header(ActionController::Base.helpers.asset_path('admin.css'), as: 'style')
      add_preload_link_header(ActionController::Base.helpers.asset_pack_path('admin.js'), as: 'script')
      ENV['imgix_domain'].split(',').each do |domain|
        add_preconnect_link_header("http#{'s' if ENV['imgix_secure'].present?}://#{domain}")
      end
    end
  end

  def set_referrer_policy
    response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
  end
end
