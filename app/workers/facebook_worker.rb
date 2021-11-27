class FacebookWorker < BufferWorker

  def perform(entry_id)
    return if !Rails.env.production?
    entry = Entry.published.find(entry_id)
    raise UnprocessedPhotoError if entry.is_photo? && !entry.photos_processed?
    post_to_buffer('facebook', text: "#{entry.plain_title}\n\n#{entry.permalink_url}")
  end
end
