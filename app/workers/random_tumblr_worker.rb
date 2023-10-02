
class RandomTumblrWorker < ApplicationWorker
  def perform
    return if ENV['SHARE_RANDOM_PHOTOS'].blank?
    logger.info "[Queue] Attempting to reblog a random entry on Tumblr."
    photoblog = Blog.first
    
    current_time = Time.current.in_time_zone(photoblog.time_zone)
    return if current_time.to_date == photoblog.entries.published.first.published_at.in_time_zone(photoblog.time_zone).to_date

    entry = Entry.find(Entry.posted_on_tumblr.where('published_at >= ?', 4.years.ago).pluck(:id).sample)
    TumblrReblogWorker.perform_async(entry.id)
  end
end
