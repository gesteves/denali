class RandomShareWorker < ApplicationWorker
  def perform(tag, platform)
    return if ENV['SHARE_RANDOM_PHOTOS'].blank?
    logger.info "[Queue] Attempting to share a random entry on #{platform}."

    photoblog = Blog.first
    current_time = Time.current.in_time_zone(photoblog.time_zone)
    return if current_time.to_date == photoblog.entries.published.first.published_at.in_time_zone(photoblog.time_zone).to_date

    entry = find_eligible_entry(tag, platform)
    return if entry.blank?

    case platform
    when 'Bluesky'
      BlueskyWorker.perform_async(entry.id, entry.bluesky_caption)
    when 'Mastodon'
      MastodonWorker.perform_async(entry.id, entry.mastodon_caption)
    when 'Instagram'
      InstagramWorker.perform_async(entry.id, entry.instagram_caption)
    when 'Tumblr'
      TumblrReblogWorker.perform_async(entry.id)
    end
  end

  private

  def find_eligible_entry(tag, platform)
    photoblog = Blog.first

    eligible_entry_ids = case platform
    when 'Bluesky'
      photoblog.entries.published.tagged_with(tag).where(post_to_bluesky: true).pluck(:id)
    when 'Mastodon'
      photoblog.entries.published.tagged_with(tag).where(post_to_mastodon: true).pluck(:id)
    when 'Instagram'
      photoblog.entries.published.tagged_with(tag).where(post_to_instagram: true).pluck(:id)
    when 'Tumblr'
      photoblog.entries.posted_on_tumblr.tagged_with(tag).pluck(:id)
    end

    recently_shared_ids = $redis.lrange("recently_shared:#{platform.downcase}", 0, -1)
    eligible_entry_ids -= recently_shared_ids.map(&:to_i)

    eligible_entry_ids.empty? ? nil : Entry.find(eligible_entry_ids.sample)
  end
end
