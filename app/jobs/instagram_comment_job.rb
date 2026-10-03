# Posts an Instagram post's hashtags as its first comment.
class InstagramCommentJob < ApplicationJob
  # A comment is about a post that just went up; one still failing after six hours is better
  # dropped than posted weeks late, which is where Sidekiq's default retries would take it.
  sidekiq_options queue: 'high', retry_for: 6.hours.to_i

  def self.retry_delay(count, exception)
    exception.is_a?(MetaAuthError) ? :discard : super
  end

  def perform(entry_id, instagram_post_id)
    return if !Rails.env.production?
    return if ENV['INSTAGRAM_APP_ID'].blank? || ENV['INSTAGRAM_APP_SECRET'].blank?

    entry = Entry.with_share_includes.find_by(id: entry_id)
    return if entry.nil?

    comment = entry.instagram_hashtags
    return if comment.blank?

    instagram_account = entry.user.instagram_account
    return if instagram_account.blank?

    instagram = Instagram.new(
      app_id: ENV['INSTAGRAM_APP_ID'],
      app_secret: ENV['INSTAGRAM_APP_SECRET'],
      social_account: instagram_account
    )

    instagram.post_comment(
      media_id: instagram_post_id,
      message: comment
    )
  end
end
