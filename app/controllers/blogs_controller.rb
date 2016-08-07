class BlogsController < ApplicationController
  before_action :check_if_user_has_visited

  def about
    expires_in 24.hours, public: true
    fresh_when @photoblog, public: true
  end
end
