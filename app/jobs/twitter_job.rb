class TwitterJob < BufferJob
  queue_as :default

  def perform(entry)
    max_length = 230 # 280 characters - 25 for the image url - 25 for the permalink url
    caption = entry.tweet_text.present? ? entry.tweet_text : entry.plain_title
    text = "#{truncate(caption, length: max_length, omission: '…')} #{entry.permalink_url}"
    image_url = entry.photos.first.url(w: 2048, fm: 'jpg')
    thumbnail_url = entry.photos.first.url(w: 512, fm: 'jpg')

    ids = get_profile_ids('twitter')
    post_to_buffer(ids, text, image_url, thumbnail_url)
  end
end
