class GoogleJob < ApplicationJob
  queue_as :default

  def perform
    response = HTTParty.get("https://www.google.com/ping?sitemap=#{CGI.escape sitemap_index_url}") if Rails.env.production?
    if response.code >= 400
      logger.error "Submitting sitemap to Google failed with status #{response.code}"
    end
  end
end
