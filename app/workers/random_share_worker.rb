class RandomShareWorker < ApplicationWorker
  def perform
    logger.info "[Queue] Attempting to share a random entry."
    photoblog = Blog.first
    return if photoblog.entries.published.first.published_at >= 1.day.ago
    entry = Entry.find(Entry.published.where('published_at >= ?', 4.years.ago).pluck(:id).sample)
    MastodonWorker.perform_async(entry.id, entry.mastodon_caption) if entry.post_to_mastodon
    BlueskyWorker.perform_async(entry.id, entry.bluesky_caption) if entry.post_to_bluesky
  end
end
