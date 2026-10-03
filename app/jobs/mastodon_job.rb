class MastodonJob < ShareJob
  def self.available_for?(user)
    user&.mastodon_account.present?
  end

  # @param text [String, nil] the caption. Without one, the job builds the entry's
  #   caption when it runs rather than when it was enqueued, so an entry
  #   published straight from the form gets the tags and EXIF details that are
  #   only filled in after it's saved.
  def perform(entry_id, text = nil)
    entry = shareable_entry(entry_id)
    return if entry.nil? || !self.class.available_for?(entry.user)

    text ||= entry.mastodon_caption
    mastodon = Mastodon.from_social_account(entry.user.mastodon_account)
    media_ids = entry.photos.take(Mastodon::MAX_MEDIA_ATTACHMENTS).map { |p| mastodon.upload_media(url: p.mastodon_url, alt_text: p.alt_text, focal_point: p.mastodon_focal_point)['id'] }
    # The jid survives Sidekiq retries, so a retry after a post that went through
    # (but the job failed later) gets the original status back instead of a duplicate.
    mastodon.create_status(text: text, media_ids: media_ids, sensitive: entry.is_sensitive?, spoiler_text: entry.content_warning,
                           idempotency_key: ("denali-#{entry.id}-#{jid}" if jid.present?))
    record_share(entry, 'mastodon')
  end
end
