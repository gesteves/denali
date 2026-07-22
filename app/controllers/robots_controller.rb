class RobotsController < ApplicationController
  before_action :set_max_age
  before_action -> { set_cache_tags(CacheTags::BLOG) }

  def show
    respond_to do |format|
      format.txt
    end
  end
end
