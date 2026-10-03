class BlueskyJob < ShareJob
  def self.retry_delay(count, exception)
    case exception
    when BlueskyPermanentError, Bluesky::AuthenticationError
      # An empty or over-long post, a reply target we can't read, or credentials Bluesky refuses.
      # None of those get better by trying again for a day.
      :discard
    when AtProto::RateLimitedError
      # The PDS told us when it will accept writes again, so wait that long rather than burning
      # retries against a limit that hasn't lifted.
      exception.retry_after
    else
      super
    end
  end

  def self.available_for?(user)
    user&.bluesky_account.present?
  end

  # @param text [String, nil] the caption. Without one, the job builds the entry's
  #   caption when it runs rather than when it was enqueued, so an entry
  #   published straight from the form gets the tags and EXIF details that are
  #   only filled in after it's saved.
  # @param rkey [String, nil] the record key the post is written at, made by the caller with
  #   Bluesky.new_tid before it enqueued this job. It is what makes a retry replace the post
  #   rather than add another one. A job enqueued before this argument existed arrives without it
  #   and mints its own, which is the behaviour it already had.
  def perform(entry_id, text, in_reply_to = nil, quote = nil, rkey = nil)
    entry = shareable_entry(entry_id)
    return if entry.nil? || !self.class.available_for?(entry.user)

    text ||= entry.bluesky_caption
    bluesky = Bluesky.from_social_account(entry.user.bluesky_account)

    photos = entry.photos.take(Bluesky::MAX_PHOTOS).map do |p|
      { url: p.bluesky_url, alt_text: p.alt_text, width: p.width, height: p.height }
    end

    # Mastodon gets the entry's content warning as its own; Bluesky has no free-text warning, only
    # labels that readers' apps act on.
    labels = entry.is_sensitive? ? [Bluesky::SENSITIVE_LABEL] : []
    response = bluesky.skeet(rkey: rkey.presence || Bluesky.new_tid, text: text, photos: photos,
                             in_reply_to: in_reply_to, quote: quote, labels: labels)

    # Threadgates only apply to root posts; replies inherit the root post's gate.
    BlueskyThreadgateJob.perform_async(entry_id, response["uri"]) if in_reply_to.blank? && response["uri"].present?

    record_share(entry, 'bluesky') unless in_reply_to.present? || quote.present?
  end
end
