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

  def preload_assets
    if request.format.html?
      preload_asset(ActionController::Base.helpers.asset_path('admin.css'), as = 'style')
      preload_asset(ActionController::Base.helpers.asset_pack_path('admin.js'), as = 'script')
    end
  end
end
