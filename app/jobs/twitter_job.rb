class TwitterJob < BufferJob
  queue_as :default

  def perform(entry)
    max_length = 90 # 140 characters - 25 for the image url - 25 for the permalink url
    text = "#{truncate(entry.plain_title, length: max_length, omission: '…')} #{entry.permalink_url(utm_source: 'twitter.com', utm_medium: 'social')}"
    image_url = entry.photos.first.url(w: 2048, fm: 'jpg')
    thumbnail_url = entry.photos.first.url(w: 512, fm: 'jpg')
    post_to_buffer('twitter', text, image_url, thumbnail_url)
  end
end
