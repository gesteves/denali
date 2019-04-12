class InstagramWorker < BufferWorker

  def perform(entry_id)
    entry = Entry.find(entry_id)
    return if !entry.is_photo?
    opts = {
      text: entry.instagram_caption,
      media: media_hash(entry.photos.first)
    }
    facebook_place = facebook_place(entry)
    if facebook_place.present?
      opts[:service_geolocation_id] = facebook_place['id']
      opts[:service_geolocation_name] = facebook_place['name']
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

  def facebook_place(entry)
    entry_tags = entry.combined_tags.map { |t| t.slug.gsub(/-/, '') }
    place = nil
    facebook_places = YAML.load_file(Rails.root.join('config/facebook_places.yml'))
    facebook_places.each do |k, v|
      if entry_tags.include? k
        place = v
        break
      end
    end
    place
  end
end
