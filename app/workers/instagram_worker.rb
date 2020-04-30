class InstagramWorker < BufferWorker

  def perform(entry_id, now = false)
    return if !Rails.env.production?
    entry = Entry.published.find(entry_id)
    return if !entry.is_photo?

    photos = entry.photos.to_a[0..4]
    opts = {
      text: entry.instagram_caption,
      media: media_hash(photos.shift),
      now: now
    }

    if photos.present?
      opts[:extra_media] = photos.map { |p| media_hash(p) }
    else
      hashtags = entry.instagram_hashtags
      if hashtags.present?
        opts[:comment_enabled] = true
        opts[:comment_text] = hashtags
      end
      geolocation_name, geolocation_id = entry.instagram_location
      if geolocation_name.present? && geolocation_id.present?
        opts[:service_geolocation_id] = geolocation_id
        opts[:service_geolocation_name] = geolocation_name
      end
    end

    updates = post_to_buffer('instagram', opts)
    updates.map { |u| InstagramCommentWorker.perform_in(1.minute, u) }
  end

  private
  def media_hash(photo)
    {
      photo: photo.instagram_url
    }
  end
end
