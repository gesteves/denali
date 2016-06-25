class BlogsController < ApplicationController

  def about
    expires_in 24.hours, public: true
    fresh_when @photoblog
  end
end
