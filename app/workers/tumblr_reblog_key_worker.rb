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

    # Find the post.
    posts = tumblr.posts(tumblr_username, id: entry.tumblr_id)
    raise posts.to_s if posts['errors'].present? || (posts['status'].present? && posts['status'] >= 400)

    post = posts['posts'][0]
    if post['state'] == 'published'
      # If the post is published, save the ID and reblog key.
      entry.tumblr_id = post['id_string']
      entry.tumblr_reblog_key = post['reblog_key']
      entry.save!
    elsif post['state'] == 'queued'
      # If the post is queued, the Tumblr ID will change when it's published,
      # so check back after it's published (plus one hour, because Tumblr never publishes exactly when it says it will.)
      publish_time = Time.at(post['scheduled_publish_time']) + 10.minutes
      TumblrUpdateQueuedWorker.perform_at(publish_time, entry.id)
    end
  end
end
