
class RandomTumblrWorker < ApplicationWorker
  def perform
    return if ENV['SHARE_RANDOM_PHOTOS'].blank?
    logger.info "[Queue] Attempting to reblog a random entry on Tumblr."
    photoblog = Blog.first
    return if photoblog.entries.published.first.published_at >= 2.days.ago || Entry.queued.count > 0
    entry = Entry.find(Entry.posted_on_tumblr.where('published_at >= ?', 4.years.ago).pluck(:id).sample)
    TumblrReblogWorker.perform_async(entry.id)
  end
end
