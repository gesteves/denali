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
        alt_text: p.alt_text
      }
    end

    container_id = if photos.size == 1
      threads.create_photo_container(
        photo_url: photos.first[:url],
        caption: text,
        alt_text: photos.first[:alt_text],
        topic_tag: entry.threads_topic.presence,
        location_id: entry.threads_location_id
      )
    else
      threads.create_carousel_container(
        photos: photos,
        caption: text,
        topic_tag: entry.threads_topic.presence,
        location_id: entry.threads_location_id
      )
    end

    raise "Failed to create Threads container for entry #{entry_id}: container_id is blank" if container_id.blank?

    ThreadsPublishWorker.perform_in(30.seconds, entry_id, container_id)
  end
end

