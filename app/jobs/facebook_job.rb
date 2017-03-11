class FacebookJob < BufferJob
  queue_as :default

  def perform(entry)
    text = "#{entry.plain_title}\n\n#{entry.permalink_url}"
    image_url = entry.photos.first.url(w: 2048)
    post_to_buffer('facebook', text, image_url)
  end
end
