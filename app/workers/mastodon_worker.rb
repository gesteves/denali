class MastodonWorker < ApplicationWorker
  sidekiq_options queue: 'high'

  def perform(entry_id, text)
    return if !Rails.env.production?
    return if ENV['MASTODON_BASE_URL'].blank? || ENV['MASTODON_ACCESS_TOKEN'].blank?
    entry = Entry.published.find(entry_id)
    return if !entry.is_photo?
    raise UnprocessedPhotoError unless entry.photos_have_dimensions?

    mastodon = Mastodon::REST::Client.new(base_url: ENV['MASTODON_BASE_URL'], bearer_token: ENV['MASTODON_ACCESS_TOKEN'])
    media_ids = entry.photos.map { |p| mastodon.upload_media(URI.open(p.mastodon_url).path, description: p.alt_text, focus: p.mastodon_focal_point.join(',')).id }
    mastodon.create_status(text, media_ids: media_ids)
  end

end
