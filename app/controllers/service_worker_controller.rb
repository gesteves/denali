class ServiceWorkerController < ApplicationController
  before_action :set_max_age
  before_action -> { set_cache_tags(CacheTags::BLOG) }
  skip_before_action :verify_authenticity_token

  def index
  end
end
