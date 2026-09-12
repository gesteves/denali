class BlueskyThreadgateJob < ApplicationJob
  sidekiq_options queue: 'high'

  # Refer to the note in BlueskyJob: this block replaces ApplicationJob's, so it restates both
  # branches.
  sidekiq_retry_in do |count, exception|
    case exception
    when BlueskyPermanentError, Bluesky::AuthenticationError
      :discard
    when AtProto::RateLimitedError
      # The PDS told us when it will accept writes again, so wait that long rather than burning
      # retries against a limit that hasn't lifted.
      exception.retry_after
    when UnprocessedPhotoError
      count + 1
    end
  end

  def perform(entry_id, post_uri)
    return unless Rails.env.production?
    return if post_uri.blank?

    entry = Entry.find(entry_id)

    account = entry.user&.bluesky_account
    return if account.nil?

    bluesky = Bluesky.from_social_account(account)
    bluesky.create_threadgate(post_uri)
  end
end
