class ThreadsJob < ApplicationJob
  sidekiq_options queue: 'high', retry_for: 1.hour

  def perform(entry_id, text)
    return if !Rails.env.production?
    return if ENV['THREADS_APP_ID'].blank? || ENV['THREADS_APP_SECRET'].blank?

    entry = Entry.published.find(entry_id)
    return if !entry.is_photo?
    raise UnprocessedPhotoError unless entry.photos_have_dimensions?

    threads_account = entry.user.threads_account
    return if threads_account.blank?

    threads = Threads.new(
      app_id: ENV['THREADS_APP_ID'],
      app_secret: ENV['THREADS_APP_SECRET'],
      social_account: threads_account
    )

    photos = entry.photos.limit(20).map do |p|
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

    entry.update_columns(
      last_shared_on_threads_at: Time.current,
      threads_shares_count: entry.threads_shares_count + 1
    )
  end
end

