class RandomMastodonWorker < ApplicationWorker
  def perform(tag:)
    return if ENV['SHARE_RANDOM_PHOTOS'].blank?
    logger.info "[Queue] Attempting to share a random entry on Bluesky."
    photoblog = Blog.first
    entry = Entry.find(photoblog.entries.published.photo_entries.tagged_with(tag, any: true).where('published_at >= ?', 4.years.ago).pluck(:id).sample)
    MastodonWorker.perform_async(entry.id, entry.mastodon_caption) if entry.post_to_mastodon
  end
end
