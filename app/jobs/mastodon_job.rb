class MastodonJob < ApplicationJob
  sidekiq_options queue: 'high'

  def perform(entry_id, text)
    return unless Rails.env.production?

    entry = Entry.published.find(entry_id)
    return unless entry.is_photo?
    raise UnprocessedPhotoError unless entry.photos_have_dimensions?

    account = entry.user&.mastodon_account
    return if account.nil?

    mastodon = Mastodon.from_social_account(account)
    media_ids = entry.photos.take(Mastodon::MAX_MEDIA_ATTACHMENTS).map { |p| mastodon.upload_media(url: p.mastodon_url, alt_text: p.alt_text, focal_point: p.mastodon_focal_point)['id'] }
    mastodon.create_status(text: text, media_ids: media_ids, sensitive: entry.is_sensitive?, spoiler_text: entry.content_warning)
    entry.update!(
      last_shared_on_mastodon_at: Time.current,
      mastodon_shares_count: entry.mastodon_shares_count + 1
    )
  end
end
