class MastodonJob < ApplicationJob
  sidekiq_options queue: 'high'

  # @param text [String, nil] the caption. Without one, the job builds the entry's
  #   new-photo caption when it runs rather than when it was enqueued, so an entry
  #   published straight from the form gets the tags and EXIF details that are
  #   only filled in after it's saved.
  def perform(entry_id, text = nil)
    return unless Rails.env.production?

    entry = Entry.published.find(entry_id)
    return unless entry.is_photo?
    raise UnprocessedPhotoError unless entry.photos_have_dimensions?

    account = entry.user&.mastodon_account
    return if account.nil?

    text ||= entry.mastodon_caption(utm_campaign: 'new-photo')
    mastodon = Mastodon.from_social_account(account)
    media_ids = entry.photos.take(Mastodon::MAX_MEDIA_ATTACHMENTS).map { |p| mastodon.upload_media(url: p.mastodon_url, alt_text: p.alt_text, focal_point: p.mastodon_focal_point)['id'] }
    # The jid survives Sidekiq retries, so a retry after a post that went through
    # (but the job failed later) gets the original status back instead of a duplicate.
    mastodon.create_status(text: text, media_ids: media_ids, sensitive: entry.is_sensitive?, spoiler_text: entry.content_warning,
                           idempotency_key: ("denali-#{entry.id}-#{jid}" if jid.present?))
    entry.update_columns(
      last_shared_on_mastodon_at: Time.current,
      mastodon_shares_count: entry.mastodon_shares_count + 1
    )
  end
end
