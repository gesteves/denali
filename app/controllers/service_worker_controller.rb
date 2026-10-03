class ServiceWorkerController < ApplicationController
  before_action :set_max_age
  before_action -> { set_cache_tags(CacheTags::BLOG) }
  # A JavaScript response to a GET is what forgery protection's cross-origin
  # check refuses, and a service worker script is exactly that.
  skip_before_action :verify_authenticity_token

  def index
  end
end
