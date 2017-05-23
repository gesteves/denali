class FacebookJob < BufferJob
  queue_as :default

  def perform(entry)
    text = "#{entry.plain_title}\n\n#{entry.permalink_url(utm_source: 'facebook')}"
    image_url = entry.photos.first.url(w: 2048, fm: 'jpg')
    thumbnail_url = entry.photos.first.url(w: 512, fm: 'jpg')
    post_to_buffer('facebook', text, image_url, thumbnail_url)
  end
end
