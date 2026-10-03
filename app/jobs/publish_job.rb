class PublishJob < ApplicationJob
  def perform
    logger.info "[Queue] Attempting to publish a queued entry."
    photoblog = Blog.first
    # Only attempt to publish a queued entry if another one hasn't been published in the last 10 minutes
    last_published_at = photoblog.entries.published.first&.published_at
    photoblog.publish_queued_entry! unless last_published_at.present? && last_published_at >= 10.minutes.ago
  end
end
