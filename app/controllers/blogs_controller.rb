class BlogsController < ApplicationController
  before_action :set_max_age
  before_action -> { set_cache_tags(CacheTags::BLOG) }
  skip_before_action :verify_authenticity_token

  def about
    @page_title = "About – #{@photoblog.name}"
    respond_to do |format|
      format.html
    end
  end
end
