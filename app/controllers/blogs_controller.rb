class BlogsController < ApplicationController
  before_action :set_entry_max_age

  def about
    fresh_when @photoblog, public: true
  end
end
