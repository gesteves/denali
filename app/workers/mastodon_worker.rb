class MastodonWorker < ApplicationWorker
  sidekiq_options queue: 'high'

  def perform(entry_id, text)
    return if !Rails.env.production?
    return if ENV['MASTODON_BASE_URL'].blank? || ENV['MASTODON_ACCESS_TOKEN'].blank?
    entry = Entry.published.find(entry_id)
    return if !entry.is_photo?
    raise UnprocessedPhotoError unless entry.photos_have_dimensions?

    mastodon = Mastodon.new(base_url: ENV['MASTODON_BASE_URL'], bearer_token: ENV['MASTODON_ACCESS_TOKEN'])
    media_ids = entry.photos.to_a[0..4].map { |p| mastodon.upload_media(url: p.mastodon_url, alt_text: p.alt_text, focal_point: p.mastodon_focal_point)['id'] }
    mastodon.create_status(text: text, media_ids: media_ids, sensitive: entry.is_sensitive?, spoiler_text: entry.content_warning)
    entry.track_recently_shared('Mastodon')
  end

end
