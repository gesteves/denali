class ThreadsJob < ShareJob
  def self.available_for?(user)
    ENV['THREADS_APP_ID'].present? && ENV['THREADS_APP_SECRET'].present? && user&.threads_account.present?
  end

  def self.retry_delay(count, exception)
    case exception
    when MetaCaptionTooLongError
      :discard
    else
      super
    end
  end

  # @param text [String, nil] the caption. Without one, the job builds the entry's
  #   caption when it runs rather than when it was enqueued, so an entry
  #   published straight from the form gets the tags and EXIF details that are
  #   only filled in after it's saved.
  def perform(entry_id, text = nil)
    entry = shareable_entry(entry_id)
    return if entry.nil? || !self.class.available_for?(entry.user)

    text ||= entry.threads_caption
    threads = Threads.new(
      app_id: ENV['THREADS_APP_ID'],
      app_secret: ENV['THREADS_APP_SECRET'],
      social_account: entry.user.threads_account
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

