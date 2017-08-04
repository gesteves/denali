class BingJob < ApplicationJob
  include Rails.application.routes.url_helpers
  queue_as :default

  def perform
    response = HTTParty.get("https://www.bing.com/ping?sitemap=#{CGI.escape sitemap_index_url}") if Rails.env.production?
    if response.code >= 400
      logger.error "Submitting sitemap to Bing failed with status #{response.code}"
    end
  end
end
