# What writing a gate on a new Bluesky post has in common, whichever gate it is.
#
# Each gate reads its blog setting here, when the job runs, rather than in BlueskyJob. That keeps
# the decision in one place, and a job already queued when a setting changes follows the new value.
class BlueskyGateJob < ApplicationJob
  # A gate matters most while the post is new; one still failing after six hours is better dropped
  # than retried for weeks.
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

    write_gate(Bluesky.from_social_account(account), entry.blog, post_uri)
  end

  private

  # @param bluesky [Bluesky] the client for the account that wrote the post.
  # @param blog [Blog] the blog whose settings decide the gate.
  # @param post_uri [String] the at-uri of the post.
  # @return [void]
  def write_gate(bluesky, blog, post_uri)
    raise NotImplementedError, "#{self.class.name} must write its gate"
  end
end
