class AdminController < ApplicationController
  before_filter :require_login
end
