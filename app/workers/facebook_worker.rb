class FacebookWorker < BufferWorker

  def perform(entry_id, now = false)
    return if !Rails.env.production?
    entry = Entry.published.find(entry_id)
    raise PhotoNotUploadedError if entry.is_photo? && !entry.photos_processed?
    text = []
    text << entry.plain_title
    text << entry.plain_body if entry.body.present?
    text << entry.permalink_url
    text = text.join("\n\n")
    now = now
    post_to_buffer('facebook', text: text, now: now)
  end
end
