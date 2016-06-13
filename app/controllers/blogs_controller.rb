class BlogsController < ApplicationController
  before_action :check_if_user_has_visited

  def about
    expires_in 24.hours, public: true
  end
end
