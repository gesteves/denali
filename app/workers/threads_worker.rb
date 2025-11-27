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

    threads.post(
      photos: photos,
      caption: text,
      topic_tag: entry.threads_topic,
      location_id: entry.photos.first.threads_location_id
    )

    entry.update!(
      last_shared_on_threads_at: Time.current,
      threads_shares_count: entry.threads_shares_count + 1
    )
  end
end

