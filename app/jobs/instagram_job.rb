class InstagramJob < BufferJob
  queue_as :default

  def perform(entry)
    return if !entry.is_photo?
    text = entry.instagram_caption
    media = media_hash(entry.photos.first)
    buffer_opts = { text: text, media: media }
    if ENV['instagram_delay_in_minutes'].present?
      minutes = ENV['instagram_delay_in_minutes'].to_i
      if minutes == 0
        buffer_opts[:now] = true
      else
        buffer_opts[:scheduled_at] = (Time.current + minutes.minutes).beginning_of_hour.to_i
      end
    end
    post_to_buffer('instagram', buffer_opts)
  end

  private
  def media_hash(photo)
    {
      photo: photo.instagram_url,
      thumbnail: photo.url(w: 512, fm: 'jpg')
    }
 end
end
