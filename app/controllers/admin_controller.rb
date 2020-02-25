class AdminController < ApplicationController
  layout 'admin'
  before_action :block_cloudfront
  before_action :block_heroku
  before_action :no_cache
  before_action :require_login
  skip_before_action :domain_redirect
  helper_method :is_admin?

  def default_url_options
    if Rails.env.production?
      { host: ENV['admin_domain'] }
    else
      {}
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

  def block_heroku
    raise ActionController::RoutingError.new('Not Found') if request.host.match? /herokuapp\.com/
  end
end
