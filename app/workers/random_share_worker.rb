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
      if entry.present?
        BlueskyWorker.perform_async(entry.id, entry.bluesky_caption)
        record_share_in_redis(entry.id, 'Bluesky')
      end
    when 'Mastodon'
      entry = find_eligible_entry(tag, 'Mastodon')
      if entry.present?
        MastodonWorker.perform_async(entry.id, entry.mastodon_caption)
        record_share_in_redis(entry.id, 'Mastodon')
      end
    when 'Tumblr'
      entry = find_eligible_entry(tag, 'Tumblr')
      if entry.present?
        TumblrReblogWorker.perform_async(entry.id)
        record_share_in_redis(entry.id, 'Tumblr')
      end
    end
  end

  private

  def find_eligible_entry(tag, platform)
    photoblog = Blog.first

    eligible_entry_ids = case platform
    when 'Bluesky'
      photoblog.entries.published.photo_entries.tagged_with(tag, any: true).where('published_at >= ?', 4.years.ago).where(post_to_bluesky: true).pluck(:id)
    when 'Mastodon'
      photoblog.entries.published.photo_entries.tagged_with(tag, any: true).where('published_at >= ?', 4.years.ago).where(post_to_mastodon: true).pluck(:id)
    when 'Tumblr'
      photoblog.entries.posted_on_tumblr.photo_entries.tagged_with(tag, any: true).where('published_at >= ?', 4.years.ago).pluck(:id)
    end

    recently_shared_ids = $redis.lrange("randomly_shared_entries:#{platform}", 0, -1)
    eligible_entry_ids -= recently_shared_ids.map(&:to_i)

    eligible_entry_ids.empty? ? nil : Entry.find(eligible_entry_ids.sample)
  end

  def recently_shared?(entry_id, platform)
    $redis.lrange("randomly_shared_entries:#{platform}", 0, -1).include?(entry_id.to_s)
  end

  def record_share_in_redis(entry_id, platform)
    default_limit = 100

    limit = ENV['SHARE_RANDOM_PHOTOS_LIMIT']&.to_i
    limit = default_limit unless limit&.positive?
    limit -= 1

    $redis.lpush("randomly_shared_entries:#{platform}", entry_id)
    $redis.ltrim("randomly_shared_entries:#{platform}", 0, limit)
  end

end
