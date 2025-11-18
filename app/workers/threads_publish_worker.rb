class ThreadsPublishWorker < ApplicationWorker
  sidekiq_options queue: 'high'

  def perform(entry_id, container_id)
    return if !Rails.env.production?
    return if ENV['THREADS_APP_ID'].blank? || ENV['THREADS_APP_SECRET'].blank? || ENV['THREADS_ACCESS_TOKEN'].blank? || ENV['THREADS_USER_ID'].blank?
    entry = Entry.find(entry_id)
    return if !entry.is_photo?
    raise UnprocessedPhotoError unless entry.photos_have_dimensions?

    threads = Threads.new(
      app_id: ENV['THREADS_APP_ID'],
      app_secret: ENV['THREADS_APP_SECRET'],
      threads_user_id: ENV['THREADS_USER_ID']
    )

    threads.publish_container(container_id)
    entry.update_column(:last_shared_on_threads_at, Time.current)
  end
end

