class BlogsController < ApplicationController
  before_action :set_max_age
  before_action -> { set_cache_tags(CacheTags::BLOG) }

  def about
    @page_title = "About – #{@photoblog.name}"
    respond_to do |format|
      format.html
    end
  end
end
