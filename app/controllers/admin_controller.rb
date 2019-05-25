class AdminController < ApplicationController
  layout 'admin'
  before_action :block_cloudfront
  before_action :no_cache
  before_action :require_login
  skip_before_action :domain_redirect
  helper_method :is_admin?

  def default_url_options
    if Rails.env.production?
      { host: "#{ENV['HEROKU_APP_NAME']}.herokuapp.com" }
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
end
