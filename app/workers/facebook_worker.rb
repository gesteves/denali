class FacebookWorker < BufferWorker

  def perform(entry_id)
    entry = Entry.find(entry_id)
    return if !entry.is_published? || !entry.is_photo?
    text = []
    text << entry.plain_title
    text << entry.plain_body if entry.body.present?
    text << entry.permalink_url
    text = text.join("\n\n")
    if entry.is_photo?
      photos = entry.photos.to_a[0..4]
      opts = {
        text: entry.instagram_caption,
        media: media_hash(photos.shift)
      }
      opts[:extra_media] = photos.map { |p| media_hash(p) } if photos.present?
      post_to_buffer('facebook', opts)
    else
      post_to_buffer('facebook', text: text)
    end
  end
end
