class RandomShareWorker < ApplicationWorker
  def perform(tags, platforms, not_shared_in_months = 12, excluded_tags = [])
    return if ENV['SHARE_RANDOM_PHOTOS'].blank?
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
        BlueskyWorker.perform_async(entry.id, entry.bluesky_caption(utm_campaign: campaign))
      when 'Mastodon'
        MastodonWorker.perform_async(entry.id, entry.mastodon_caption(utm_campaign: campaign))
      when 'Instagram'
        InstagramWorker.perform_async(entry.id, entry.instagram_caption)
      when 'Threads'
        ThreadsWorker.perform_async(entry.id, entry.threads_caption(utm_campaign: campaign))
      end
    end
  end

  private

  def find_eligible_entry(tags, excluded_tags, platform, not_shared_in_months)
    photoblog = Blog.first
    months_ago = not_shared_in_months.months.ago

    base_query = photoblog.entries.published
    base_query = base_query.tagged_with(tags) if tags.any?
    base_query = base_query.tagged_with(excluded_tags, exclude: true) if excluded_tags.any?

    shares_column, timestamp_column, post_flag = case platform
    when 'Bluesky'
      [:bluesky_shares_count, :last_shared_on_bluesky_at, :post_to_bluesky]
    when 'Mastodon'
      [:mastodon_shares_count, :last_shared_on_mastodon_at, :post_to_mastodon]
    when 'Instagram'
      [:instagram_shares_count, :last_shared_on_instagram_at, :post_to_instagram]
    when 'Threads'
      [:threads_shares_count, :last_shared_on_threads_at, :post_to_threads]
    end

    eligible_entries = base_query
      .where(post_flag => true)
      .where("#{timestamp_column} IS NULL OR #{timestamp_column} < ?", months_ago)

    return nil if eligible_entries.empty?

    # Find the minimum share count among eligible entries
    min_shares = eligible_entries.minimum(shares_column)

    # Select only entries with the minimum share count
    least_shared = eligible_entries.where(shares_column => min_shares)

    logger.info "[Social] There are #{least_shared.count} entries#{tags.any? ? " tagged with #{tags.join(', ')}" : ""}#{excluded_tags.any? ? " excluding #{excluded_tags.join(', ')}" : ""} eligible to be shared on #{platform}."
    least_shared.sample
  end
end
