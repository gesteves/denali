class InstagramWorker < BufferWorker

  def perform(entry_id)
    entry = Entry.find(entry_id)
    return if !entry.is_photo?
    opts = {
      text: entry.instagram_caption,
      media: media_hash(entry.photos.first)
    }
    instagram_location = entry.instagram_location
    if instagram_location.present?
      opts[:service_geolocation_id] = instagram_location['id']
      opts[:service_geolocation_name] = instagram_location['name']
    end
    post_to_buffer('instagram', opts)
  end

  private
  def media_hash(photo)
    {
      photo: photo.instagram_url,
      thumbnail: photo.url(w: 512, fm: 'jpg')
    }
  end
end
