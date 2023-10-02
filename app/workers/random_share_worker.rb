
class RandomShareWorker < ApplicationWorker
  def perform(tag:, platform:)
    return if ENV['SHARE_RANDOM_PHOTOS'].blank?
    logger.info "[Queue] Attempting to share a random entry on #{platform}."
    photoblog = Blog.first
    current_time = Time.current.in_time_zone(photoblog.time_zone)
    return if current_time.to_date == photoblog.entries.published.first.published_at.in_time_zone(photoblog.time_zone).to_date

    case platform
    when 'Bluesky'
      entry = Entry.find(photoblog.entries.published.photo_entries.tagged_with(tag, any: true).where('published_at >= ?', 4.years.ago).where(post_to_bluesky: true).pluck(:id).sample)
      BlueskyWorker.perform_async(entry.id, entry.bluesky_caption) if entry.present?
    when 'Mastodon'
      entry = Entry.find(photoblog.entries.published.photo_entries.tagged_with(tag, any: true).where('published_at >= ?', 4.years.ago).where(post_to_mastodon: true).pluck(:id).sample)
      MastodonWorker.perform_async(entry.id, entry.mastodon_caption) if entry.present?
    when 'Tumblr'
      entry = Entry.find(photoblog.entries.posted_on_tumblr.photo_entries.tagged_with(tag, any: true).where('published_at >= ?', 4.years.ago).pluck(:id).sample)
      TumblrReblogWorker.perform_async(entry.id)
    end
  end
end
