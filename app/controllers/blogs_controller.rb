class BlogsController < ApplicationController
  
  def about
    expires_in 24.hours, public: true
  end
end
