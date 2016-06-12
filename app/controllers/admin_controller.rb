class AdminController < ApplicationController
  layout 'admin'
  before_action :require_login
  before_action :no_cache

  def index
    redirect_to admin_entries_path
  end
end
