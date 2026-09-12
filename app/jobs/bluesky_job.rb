class BlueskyJob < ApplicationJob
  sidekiq_options queue: 'high'

  # ⚠️ sidekiq_retry_in lives in sidekiq_options, so this block REPLACES ApplicationJob's rather
  # than adding to it. Both branches have to be here, or the UnprocessedPhotoError backoff is
  # silently lost.
  sidekiq_retry_in do |count, exception|
    case exception
    when BlueskyPermanentError, Bluesky::AuthenticationError
      # An empty or over-long post, a reply target we can't read, or credentials Bluesky refuses.
      # None of those get better by trying again for a day.
      :discard
    when UnprocessedPhotoError
      count + 1
    end
  end

  # @param rkey [String, nil] the record key the post is written at, made by the caller with
  #   Bluesky.new_tid before it enqueued this job. It is what makes a retry replace the post
  #   rather than add another one. A job enqueued before this argument existed arrives without it
  #   and mints its own, which is the behaviour it already had.
  def perform(entry_id, text, in_reply_to = nil, quote = nil, rkey = nil)
    return unless Rails.env.production?

    entry = Entry.published.find(entry_id)
    return unless entry.is_photo?
    raise UnprocessedPhotoError unless entry.photos_have_dimensions?

    account = entry.user&.bluesky_account
    return if account.nil?

    bluesky = Bluesky.from_social_account(account)

    photos = entry.photos.take(Bluesky::MAX_PHOTOS).map do |p|
      { url: p.bluesky_url, alt_text: p.alt_text, width: p.width, height: p.height }
    end

    response = bluesky.skeet(rkey: rkey.presence || Bluesky.new_tid, text: text, photos: photos,
                             in_reply_to: in_reply_to, quote: quote)

    # Threadgates only apply to root posts; replies inherit the root post's gate.
    BlueskyThreadgateJob.perform_async(entry_id, response["uri"]) if in_reply_to.blank? && response["uri"].present?

    unless in_reply_to.present? || quote.present?
      entry.update_columns(
        last_shared_on_bluesky_at: Time.current,
        bluesky_shares_count: entry.bluesky_shares_count + 1
      )
    end
  end
end
