class ThreadsJob < ShareJob
  def self.retry_delay(count, exception)
    case exception
    when MetaCaptionTooLongError
      :discard
    else
      super
    end
  end

  # @param text [String, nil] the caption. Without one, the job builds the entry's
  #   new-photo caption when it runs rather than when it was enqueued, so an entry
  #   published straight from the form gets the tags and EXIF details that are
  #   only filled in after it's saved.
  def perform(entry_id, text = nil)
    return if ENV['THREADS_APP_ID'].blank? || ENV['THREADS_APP_SECRET'].blank?

    entry = shareable_entry(entry_id)
    return if entry.nil?

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

    record_share(entry, 'threads')
  end
end

