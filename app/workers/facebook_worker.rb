class FacebookWorker < BufferWorker

  def perform(entry_id, now = false)
    return if !Rails.env.production?
    entry = Entry.published.find(entry_id)
    raise UnprocessedPhotoError if entry.is_photo? && !entry.photos_processed?
    post_to_buffer('facebook', text: entry.facebook_caption, now: now)
  end
end
