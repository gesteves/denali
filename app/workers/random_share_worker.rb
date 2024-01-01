class RandomShareWorker < ApplicationWorker
  def perform(tag, platform)
    return if ENV['SHARE_RANDOM_PHOTOS'].blank?
    logger.info "[Queue] Attempting to share a random entry on #{platform}."

    photoblog = Blog.first
    current_time = Time.current.in_time_zone(photoblog.time_zone)
    return if current_time.to_date == photoblog.entries.published.first.published_at.in_time_zone(photoblog.time_zone).to_date

    case platform
    when 'Bluesky'
      entry = find_eligible_entry(tag, 'Bluesky')
      BlueskyWorker.perform_async(entry.id, entry.bluesky_caption) if entry.present?
    when 'Mastodon'
      entry = find_eligible_entry(tag, 'Mastodon')
      MastodonWorker.perform_async(entry.id, entry.mastodon_caption) if entry.present?
    when 'Tumblr'
      entry = find_eligible_entry(tag, 'Tumblr')
      TumblrReblogWorker.perform_async(entry.id) if entry.present?
    end
  end

  private

  def find_eligible_entry(tag, platform)
    photoblog = Blog.first

    eligible_entry_ids = case platform
    when 'Bluesky'
      photoblog.entries.published.photo_entries.tagged_with(tag).tagged_with("Black & White").tagged_with("United States").where(post_to_bluesky: true).pluck(:id)
    when 'Mastodon'
      photoblog.entries.published.photo_entries.tagged_with(tag).tagged_with("Black & White").tagged_with("United States").where(post_to_mastodon: true).pluck(:id)
    when 'Tumblr'
      photoblog.entries.posted_on_tumblr.photo_entries.tagged_with(tag).pluck(:id)
    end

    recently_shared_ids = $redis.lrange("recently_shared:#{platform.downcase}", 0, -1)
    eligible_entry_ids -= recently_shared_ids.map(&:to_i)

    eligible_entry_ids.empty? ? nil : Entry.find(eligible_entry_ids.sample)
  end
end
