class ThreadsWorker < ApplicationWorker
  sidekiq_options queue: 'high'

  def perform(entry_id, text)
    return if !Rails.env.production?
    return if ENV['THREADS_APP_ID'].blank? || ENV['THREADS_APP_SECRET'].blank? || ENV['THREADS_ACCESS_TOKEN'].blank? || ENV['THREADS_USER_ID'].blank?
    entry = Entry.published.find(entry_id)
    return if !entry.is_photo?
    raise UnprocessedPhotoError unless entry.photos_have_dimensions?

    threads = Threads.new(
      app_id: ENV['THREADS_APP_ID'],
      app_secret: ENV['THREADS_APP_SECRET'],
      threads_user_id: ENV['THREADS_USER_ID']
    )

    photos = entry.photos.to_a[0..19].map do |p|
      {
        url: p.threads_url,
        alt_text: p.alt_text,
        latitude: p.latitude,
        longitude: p.longitude
      }
    end

    if photos.size == 1
      # Post a single photo
      threads.post_photo(
        photo_url: photos.first[:url],
        caption: text,
        alt_text: photos.first[:alt_text],
        latitude: photos.first[:latitude],
        longitude: photos.first[:longitude],
        topic_tag: entry.threads_topic.presence
      )
    else
      # Post as a carousel (2-20 photos)
      threads.post_carousel(
        photos: photos,
        caption: text,
        topic_tag: entry.threads_topic.presence
      )
    end

    # Update timestamp if the field exists
    entry.update_column(:last_shared_on_threads_at, Time.current)
  end
end

