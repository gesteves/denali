class BlogsController < ApplicationController
  before_action :set_max_age
  skip_before_action :verify_authenticity_token

  def about
    if stale?(@photoblog, public: true)
      @page_title = "About – #{@photoblog.name}"
      respond_to do |format|
        format.html
      end
    end
  end
end
