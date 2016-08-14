class BlogsController < ApplicationController
  before_action :check_if_user_has_visited
  before_action :set_max_age, only: [:about]

  def about
    fresh_when @photoblog, public: true
  end
end
