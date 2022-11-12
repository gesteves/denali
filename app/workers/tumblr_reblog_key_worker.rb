class TumblrReblogKeyWorker < ApplicationWorker
  sidekiq_options queue: 'low'

  def perform(entry_id)
    return if !Rails.env.production?
    return if ENV['TUMBLR_CONSUMER_KEY'].blank? || ENV['TUMBLR_CONSUMER_SECRET'].blank? || ENV['TUMBLR_ACCESS_TOKEN'].blank? || ENV['TUMBLR_ACCESS_TOKEN_SECRET'].blank?

    entry = Entry.published.find(entry_id)
    return if entry.tumblr_id.blank?

    tumblr_username = entry.blog.tumblr_username
    return if tumblr_username.blank?

    tumblr = Tumblr::Client.new({
      consumer_key: ENV['TUMBLR_CONSUMER_KEY'],
      consumer_secret: ENV['TUMBLR_CONSUMER_SECRET'],
      oauth_token: ENV['TUMBLR_ACCESS_TOKEN'],
      oauth_token_secret: ENV['TUMBLR_ACCESS_TOKEN_SECRET']
    })

    posts = tumblr.posts(tumblr_username, id: entry.tumblr_id)
    raise posts.to_s if posts['errors'].present? || (posts['status'].present? && posts['status'] >= 400)

    post = posts['posts'][0]
    reblog_key = post['reblog_key']
    entry.reblog_key = reblog_key
    entry.save!
  end
end
