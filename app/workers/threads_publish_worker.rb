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

    status = threads.get_container_status(container_id)

    case status
    when 'FINISHED'
      threads.publish_container(container_id)
      entry.update!(last_shared_on_threads_at: Time.current)
    when 'PUBLISHED'
      Rails.logger.info "Media container #{container_id} for entry #{entry_id} is already published"
      return
    when 'ERROR'
      raise "Media container #{container_id} failed with ERROR status"
    when 'EXPIRED'
      Rails.logger.info "Media container #{container_id} for entry #{entry_id} expired before it could be published"
      return
    when 'IN_PROGRESS'
      raise "Media container #{container_id} is still in progress"
    else
      raise "Unknown container status: #{status} for container #{container_id}"
    end
  end
end

