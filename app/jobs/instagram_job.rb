class InstagramJob < BufferJob
  queue_as :default

  def perform(entry)
    return if !entry.is_photo?
    text = entry.instagram_caption
    ids = get_profile_ids('instagram')
    media = media_hash(entry.photos.first)
    post_to_buffer(ids, text, media)
  end

  private
  def media_hash(photo)
    {
      photo: photo.instagram_url,
      thumbnail: photo.url(w: 512, fm: 'jpg')
    }
 end
end
