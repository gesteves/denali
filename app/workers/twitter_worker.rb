class TwitterWorker < BufferWorker
  sidekiq_options queue: 'high'

  def perform(entry_id, now = false)
    return if !Rails.env.production?
    entry = Entry.published.find(entry_id)
    raise UnprocessedPhotoError if entry.is_photo? && !entry.photos_processed?

    if entry.is_photo?
      photos = entry.photos.to_a[0..4]
      opts = {
        text: entry.twitter_caption,
        media: media_hash(photos.shift)
      }
      opts[:extra_media] = photos.map { |p| media_hash(p) } if photos.present?
      post_to_buffer('twitter', opts)
    else
      post_to_buffer('twitter', text: entry.twitter_caption)
    end
  end

  private
  def media_hash(photo)
    media = {
      photo: photo.twitter_url,
    }
    media[:alt_text] = photo.alt_text if photo.alt_text.present?
    media
  end
end
