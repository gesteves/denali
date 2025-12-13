class RandomShareWorker < ApplicationWorker
  def perform(tags, platforms, not_shared_in_months = 12, excluded_tags = [])
    return if !Rails.env.production?
    tags = Array(tags)
    platforms = Array(platforms)
    excluded_tags = Array(excluded_tags)
    not_shared_in_months = not_shared_in_months.to_i
    return if platforms.empty?
    logger.info "[Social] Attempting to share a random entry#{tags.any? ? " with tags #{tags.join(', ')}" : ""}#{excluded_tags.any? ? " excluding tags #{excluded_tags.join(', ')}" : ""} on #{platforms.join(', ')}."

    campaign = tags.empty? ? "random" : "random-#{tags.join(' ').parameterize}"

    platforms.each do |platform|
      entry = find_eligible_entry(tags, excluded_tags, platform, not_shared_in_months)
      next if entry.blank?
      logger.info "[Social] Sharing \"#{entry.title}\" (#{entry.permalink_url}) on #{platform}."
      case platform
      when 'Bluesky'
        BlueskyWorker.perform_in(rand(1..60).minutes, entry.id, entry.bluesky_caption(utm_campaign: campaign))
      when 'Mastodon'
        MastodonWorker.perform_in(rand(1..60).minutes, entry.id, entry.mastodon_caption(utm_campaign: campaign))
      when 'Instagram'
        InstagramWorker.perform_in(rand(1..60).minutes, entry.id, entry.instagram_caption)
      when 'Threads'
        ThreadsWorker.perform_in(rand(1..60).minutes, entry.id, entry.threads_caption(utm_campaign: campaign))
      end
    end
  end

  private

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
