class TwitterJob < BufferJob
  queue_as :default

  def perform(entry)
    max_length = 90 # 140 characters - 25 for the image url - 25 for the permalink url
    text = "#{truncate(entry.plain_title, length: max_length, omission: '…')} #{entry.permalink_url}"
    image_url = entry.photos.first.url(w: 2048)
    post_to_buffer('twitter', text, image_url)
  end
end
