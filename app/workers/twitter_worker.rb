class TwitterWorker < BufferWorker

  def perform(entry_id)
    entry = Entry.find(entry_id)
    return if !entry.is_published?
    max_length = 230 # 280 characters - 25 for the image url - 25 for the permalink url
    caption = entry.tweet_text.present? ? entry.tweet_text : entry.plain_title
    text = "#{truncate(caption, length: max_length, omission: '…')} #{entry.permalink_url}"
    if entry.is_photo?
      media = media_hash(entry.photos.first, alt_text: true)
      post_to_buffer('twitter', text: text, media: media)
    else
      post_to_buffer('twitter', text: text)
    end
  end
end
