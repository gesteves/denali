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

  def share(job_class, entry_id, caption, share_immediately)
    if share_immediately
      job_class.perform_async(entry_id, caption)
    else
      job_class.perform_in(rand(0..60).minutes, entry_id, caption)
    end
  end

  def find_eligible_entry(tags, excluded_tags, platform, not_shared_in_months)
    photoblog = Blog.first
    not_shared_in = not_shared_in_months.months

    eligible_entries = photoblog.entries.eligible_for_random_share(
      platform: platform,
      tags: tags,
      excluded_tags: excluded_tags,
      not_shared_in: not_shared_in
    )

    return nil if eligible_entries.blank? || eligible_entries.empty?

    logger.info "[Social] There are #{eligible_entries.count} entries#{tags.any? ? " tagged with #{tags.join(', ')}" : ""}#{excluded_tags.any? ? " excluding #{excluded_tags.join(', ')}" : ""} eligible to be shared on #{platform}."
    eligible_entries.sample
  end
end
