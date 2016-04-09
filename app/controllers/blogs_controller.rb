class BlogsController < ApplicationController
  before_action :set_max_age, :check_if_user_has_visited

  def about
  end
end
