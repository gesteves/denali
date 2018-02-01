class InstagramJob < BufferJob
  queue_as :default

  def perform(entry)
    text_array = []
    text_array << entry.plain_title
    text_array << entry.plain_body if entry.body.present?
    text_array << entry.instagram_hashtags

    text = text_array.join("\n\n")

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
