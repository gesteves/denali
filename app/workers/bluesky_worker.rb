class BlueskyWorker < ApplicationWorker
  sidekiq_options queue: 'high'

  def perform(entry_id, text)
    return if !Rails.env.production?
    return if ENV['BLUESKY_BASE_URL'].blank? || ENV['BLUESKY_EMAIL'].blank? || ENV['BLUESKY_PASSWORD'].blank?
    entry = Entry.published.find(entry_id)
    return if !entry.is_photo?
    raise UnprocessedPhotoError unless entry.photos_have_dimensions?

    bluesky = Bluesky.new(base_url: ENV['BLUESKY_BASE_URL'], email: ENV['BLUESKY_EMAIL'], password: ENV['BLUESKY_PASSWORD'])
    photos = entry.photos.to_a[0..4].map { |p| { url: p.bluesky_url, alt_text: p.alt_text } }
    bluesky.skeet(text: text, photos: photos)
    entry.track_recently_shared('Bluesky')
  end

end
