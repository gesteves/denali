class InstagramPublishWorker < ApplicationWorker
  sidekiq_options queue: 'high'
  sidekiq_options retry_for: 5.minutes

  def perform(entry_id, container_id, update_timestamp = true)
    return if !Rails.env.production?
    return if ENV['INSTAGRAM_APP_ID'].blank? || ENV['INSTAGRAM_APP_SECRET'].blank? || ENV['INSTAGRAM_ACCESS_TOKEN'].blank? || ENV['INSTAGRAM_ACCOUNT_ID'].blank?
    entry = Entry.find(entry_id)
    return if !entry.is_photo?
    raise UnprocessedPhotoError unless entry.photos_have_dimensions?
    instagram = Instagram.new(
      app_id: ENV['INSTAGRAM_APP_ID'],
      app_secret: ENV['INSTAGRAM_APP_SECRET'],
      ig_account_id: ENV['INSTAGRAM_ACCOUNT_ID']
    )

    status = instagram.get_container_status(container_id)

    case status
    when 'IN_PROGRESS'
      raise MediaContainerInProgressError, "Media container #{container_id} for entry #{entry_id} is still in progress"
    when 'FINISHED'
      instagram.publish_container(container_id)
      entry.update!(last_shared_on_instagram_at: Time.current) if update_timestamp
    when 'PUBLISHED'
      Rails.logger.info "Media container #{container_id} for entry #{entry_id} is already published"
      return
    when 'EXPIRED'
      Rails.logger.info "Media container #{container_id} for entry #{entry_id} expired before it could be published"
      return
    when 'ERROR'
      raise "Media container #{container_id} for entry #{entry_id} failed with ERROR status"
    else
      raise "Media container #{container_id} for entry #{entry_id} has unexpected status: #{status}"
    end
  end
end
