class InstagramCommentWorker < ApplicationWorker
  sidekiq_options queue: 'high'

  def perform(entry_id, instagram_post_id)
    return if !Rails.env.production?
    return if ENV['INSTAGRAM_APP_ID'].blank? || ENV['INSTAGRAM_APP_SECRET'].blank? || ENV['INSTAGRAM_ACCESS_TOKEN'].blank? || ENV['INSTAGRAM_ACCOUNT_ID'].blank?
    entry = Entry.find(entry_id)

    comment = entry.instagram_hashtags
    return if comment.blank?

    instagram = Instagram.new(
      app_id: ENV['INSTAGRAM_APP_ID'],
      app_secret: ENV['INSTAGRAM_APP_SECRET'],
      ig_account_id: ENV['INSTAGRAM_ACCOUNT_ID']
    )

    instagram.post_comment(
      media_id: instagram_post_id,
      message: comment
    )
  end
end

