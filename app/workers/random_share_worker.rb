class RandomShareWorker < ApplicationWorker
  def perform(tags = nil, platform)
    return if ENV['SHARE_RANDOM_PHOTOS'].blank?
    # Convert to array if a single tag is passed, or use empty array if nil
    tags = Array(tags)
    logger.info "[Social] Attempting to share a random entry#{tags.any? ? " with tags #{tags.join(', ')}" : ""} on #{platform}."

    entry = find_eligible_entry(tags, platform)
    return if entry.blank?

    case platform
    when 'Bluesky'
      BlueskyWorker.perform_async(entry.id, entry.bluesky_caption)
    when 'Mastodon'
      MastodonWorker.perform_async(entry.id, entry.mastodon_caption)
    end
  end

  private

  def find_eligible_entry(tags, platform)
    photoblog = Blog.first
    months = (ENV['RANDOM_SHARING_MONTHS_THRESHOLD'] || 6).to_i
    months_ago = months.months.ago

    base_query = photoblog.entries.published
    base_query = base_query.tagged_with(tags) if tags.any?

    eligible_entries = case platform
    when 'Bluesky'
      base_query.where(post_to_bluesky: true)
               .where("last_shared_on_bluesky_at IS NULL OR last_shared_on_bluesky_at < ?", months_ago)
    when 'Mastodon'
      base_query.where(post_to_mastodon: true)
               .where("last_shared_on_mastodon_at IS NULL OR last_shared_on_mastodon_at < ?", months_ago)
    end
    logger.info "[Social] There are #{eligible_entries.size} entries#{tags.any? ? " tagged with #{tags.join(', ')}" : ""} eligible to be shared on #{platform}."
    eligible_entries.sample
  end
end
