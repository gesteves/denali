class RandomShareWorker < ApplicationWorker
  def perform(tags, platform)
    return if ENV['SHARE_RANDOM_PHOTOS'].blank?
    # Convert to array if a single tag is passed
    tags = Array(tags)
    logger.info "[Social] Attempting to share a random entry with tags #{tags.join(', ')} on #{platform}."

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

    eligible_entries = case platform
    when 'Bluesky'
      photoblog.entries.published
               .tagged_with(tags)
               .where(post_to_bluesky: true)
               .where("last_shared_on_bluesky_at IS NULL OR last_shared_on_bluesky_at < ?", months_ago)
    when 'Mastodon'
      photoblog.entries.published
               .tagged_with(tags)
               .where(post_to_mastodon: true)
               .where("last_shared_on_mastodon_at IS NULL OR last_shared_on_mastodon_at < ?", months_ago)
    end
    logger.info "[Social] There are #{eligible_entries.size} entries tagged with #{tags.join(', ')} eligible to be shared on #{platform}."
    eligible_entries.sample
  end
end
