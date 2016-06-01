class AdminController < ApplicationController
  layout 'admin'
  before_action :block_cloudfront
  before_action :require_login
  before_action :no_cache
  skip_before_action :domain_redirect

  def index
    redirect_to admin_entries_path
  end
end
