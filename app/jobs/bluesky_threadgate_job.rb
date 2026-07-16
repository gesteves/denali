class BlueskyThreadgateJob < ApplicationJob
  sidekiq_options queue: 'high'

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
