class InstagramWorker < BufferWorker

  def perform(entry_id)
    begin
      entry = Entry.find(entry_id)
    rescue ActiveRecord::RecordNotFound
      return
    end
    return if !entry.is_photo?

    photos = entry.photos.to_a[0..4]
    opts = {
      text: entry.instagram_caption,
      media: media_hash(photos.shift)
    }
    opts[:extra_media] = photos.map { |p| media_hash(p) } if photos.present?

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
