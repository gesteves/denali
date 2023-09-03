class RandomMastodonWorker < ApplicationWorker
  def perform
    return if ENV['SHARE_RANDOM_PHOTOS'].blank?
    logger.info "[Queue] Attempting to share a random entry on Mastodon."
    photoblog = Blog.first
    return if photoblog.entries.published.first.published_at >= 2.days.ago || Entry.queued.count > 0
    entry = Entry.find(Entry.published.where('published_at >= ?', 4.years.ago).pluck(:id).sample)
    MastodonWorker.perform_async(entry.id, entry.mastodon_caption) if entry.post_to_mastodon
  end
end
