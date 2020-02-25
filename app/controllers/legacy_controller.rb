class LegacyController < ApplicationController
  skip_before_action :verify_authenticity_token

  def home
    http_cache_forever(public: true) do
      redirect_to(root_url, status: 301)
    end
  end

  def feed
    http_cache_forever(public: true) do
      redirect_to(feed_url, status: 301)
    end
  end
end
