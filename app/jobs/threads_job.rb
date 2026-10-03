class ThreadsJob < ApplicationJob
  sidekiq_options queue: 'high'

  # ⚠️ This block replaces ApplicationJob's rather than adding to it, so it has to restate the
  # UnprocessedPhotoError branch as well.
  sidekiq_retry_in do |count, exception|
    case exception
    when MetaCaptionTooLongError
      :discard
    when UnprocessedPhotoError
      count + 1
    end
  end

  # @param text [String, nil] the caption. Without one, the job builds the entry's
  #   new-photo caption when it runs rather than when it was enqueued, so an entry
  #   published straight from the form gets the tags and EXIF details that are
  #   only filled in after it's saved.
  def perform(entry_id, text = nil)
    return if !Rails.env.production?
    return if ENV['THREADS_APP_ID'].blank? || ENV['THREADS_APP_SECRET'].blank?

    entry = Entry.published.find(entry_id)
    return if !entry.is_photo?
    raise UnprocessedPhotoError unless entry.photos_have_dimensions?

    threads_account = entry.user.threads_account
    return if threads_account.blank?

    text ||= entry.threads_caption(utm_campaign: 'new-photo')
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

    entry.photos.limit(20).each { |p| p.warm_cache(p.threads_url) }

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

