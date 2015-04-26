class AdminController < ApplicationController
  layout 'admin'
  before_filter :require_login

  def index
    redirect_to admin_entries_path
  end
end
