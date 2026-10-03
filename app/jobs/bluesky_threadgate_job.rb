# Limits who can reply to a new Bluesky post (see Bluesky::THREADGATE_ALLOW_RULES).
class BlueskyThreadgateJob < ApplicationJob
  # The gate matters most while the post is new; one still failing after six hours is better
  # dropped than retried for weeks.
  sidekiq_options queue: 'high', retry_for: 6.hours.to_i

  def self.retry_delay(count, exception)
    case exception
    when BlueskyPermanentError, Bluesky::AuthenticationError
      :discard
    when AtProto::RateLimitedError
      # The PDS told us when it will accept writes again, so wait that long rather than burning
      # retries against a limit that hasn't lifted.
      exception.retry_after
    else
      super
    end
  end

  def perform(entry_id, post_uri)
    return unless Rails.env.production?
    return if post_uri.blank?

    entry = Entry.find_by(id: entry_id)
    return if entry.nil?

    account = entry.user&.bluesky_account
    return if account.nil?

    bluesky = Bluesky.from_social_account(account)
    bluesky.create_threadgate(post_uri)
  end
end
