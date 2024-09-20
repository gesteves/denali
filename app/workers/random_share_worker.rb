class RandomShareWorker < ApplicationWorker
  def perform(tag, platform)
    return if ENV['SHARE_RANDOM_PHOTOS'].blank?
    logger.info "[Social] Attempting to share a random entry on #{platform}."

    photoblog = Blog.first
    current_time = Time.current.in_time_zone(photoblog.time_zone)
    return if Entry.queued.count > 0 && current_time.to_date == photoblog.entries.published.first.published_at.in_time_zone(photoblog.time_zone).to_date

    entry = find_eligible_entry(tag, platform)
    return if entry.blank?

    case platform
    when 'Bluesky'
      BlueskyWorker.perform_async(entry.id, entry.bluesky_caption)
    when 'Mastodon'
      MastodonWorker.perform_async(entry.id, entry.mastodon_caption)
    when 'Instagram'
      InstagramWorker.perform_async(entry.id, entry.instagram_caption)
    end
  end

  private

  def find_eligible_entry(tag, platform)
    photoblog = Blog.first
    months = (ENV['RANDOM_SHARING_MONTHS_THRESHOLD'] || 6).to_i
    months_ago = months.months.ago

    eligible_entries = case platform
    when 'Bluesky'
      photoblog.entries.published
               .tagged_with(tag)
               .where(post_to_bluesky: true)
               .where("last_shared_on_bluesky_at IS NULL OR last_shared_on_bluesky_at < ?", months_ago)
    when 'Mastodon'
      photoblog.entries.published
               .tagged_with(tag)
               .where(post_to_mastodon: true)
               .where("last_shared_on_mastodon_at IS NULL OR last_shared_on_mastodon_at < ?", months_ago)
    when 'Instagram'
      photoblog.entries.published
               .tagged_with(tag)
               .where(post_to_instagram: true)
               .where("last_shared_on_instagram_at IS NULL OR last_shared_on_instagram_at < ?", months_ago)
    end
    logger.info "[Social] There are #{eligible_entries.size} #{tag} entries eligible to be shared on #{platform}."
    eligible_entries.sample
  end
end
