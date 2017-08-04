class SitemapJob < ApplicationJob
  queue_as :default

  def perform(url)
    response = HTTParty.get(url) if Rails.env.production?
    if response.code >= 400
      logger.error "Submitting sitemap to #{url} failed with status #{response.code}"
    end
  end
end
