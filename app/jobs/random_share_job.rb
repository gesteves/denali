class RandomShareJob < ApplicationJob
  def perform(tags, platforms, not_shared_in_months = 12, excluded_tags = [], share_immediately = false)
    return if !Rails.env.production?
    return if Entry.published.where('published_at > ?', 1.hour.ago).exists?
    tags = Array(tags)
    platforms = Array(platforms)
    excluded_tags = Array(excluded_tags)
    not_shared_in_months = not_shared_in_months.to_i
    return if platforms.empty?
    logger.info "[Social] Attempting to share a random entry#{tags.any? ? " with tags #{tags.join(', ')}" : ""}#{excluded_tags.any? ? " excluding tags #{excluded_tags.join(', ')}" : ""} on #{platforms.join(', ')}."

    campaign = tags.empty? ? "random" : "random-#{tags.join(' ').parameterize}"

    platforms.each do |platform|
      next if recently_shared_on?(platform)
      entry = find_eligible_entry(tags, excluded_tags, platform, not_shared_in_months)
      next if entry.blank?
      logger.info "[Social] Sharing \"#{entry.title}\" (#{entry.permalink_url}) on #{platform}."
      case platform
      when 'Bluesky'
        share(BlueskyJob, entry.id, entry.bluesky_caption(utm_campaign: campaign), share_immediately)
      when 'Mastodon'
        share(MastodonJob, entry.id, entry.mastodon_caption(utm_campaign: campaign), share_immediately)
      when 'Instagram'
        share(InstagramJob, entry.id, entry.instagram_caption, share_immediately)
      when 'Threads'
        share(ThreadsJob, entry.id, entry.threads_caption(utm_campaign: campaign), share_immediately)
      end
    end
  end

  private

  def recently_shared_on?(platform)
    column = case platform
    when 'Bluesky' then 'last_shared_on_bluesky_at'
    when 'Mastodon' then 'last_shared_on_mastodon_at'
    when 'Instagram' then 'last_shared_on_instagram_at'
    when 'Threads' then 'last_shared_on_threads_at'
    end
    return false if column.nil?
    Entry.where("#{column} > ?", 1.hour.ago).exists?
  end

  def share(job_class, entry_id, caption, share_immediately)
    if share_immediately
      job_class.perform_async(entry_id, caption)
    else
      job_class.perform_in(rand(0..59).minutes, entry_id, caption)
    end
  end

  def find_eligible_entry(tags, excluded_tags, platform, not_shared_in_months)
    photoblog = Blog.first
    not_shared_in = not_shared_in_months.months

    base_query = photoblog.entries.published
    base_query = base_query.tagged_with(tags) if tags.any?
    base_query = base_query.tagged_with(excluded_tags, exclude: true) if excluded_tags.any?

    eligible_entries = case platform
    when 'Bluesky'
      base_query.shareable_on_bluesky(not_shared_in: not_shared_in).with_minimum_bluesky_shares
    when 'Mastodon'
      base_query.shareable_on_mastodon(not_shared_in: not_shared_in).with_minimum_mastodon_shares
    when 'Instagram'
      base_query.shareable_on_instagram(not_shared_in: not_shared_in).with_minimum_instagram_shares
    when 'Threads'
      base_query.shareable_on_threads(not_shared_in: not_shared_in).with_minimum_threads_shares
    end

    return nil if eligible_entries.empty?

    logger.info "[Social] There are #{eligible_entries.count} entries#{tags.any? ? " tagged with #{tags.join(', ')}" : ""}#{excluded_tags.any? ? " excluding #{excluded_tags.join(', ')}" : ""} eligible to be shared on #{platform}."
    eligible_entries.sample
  end
end
