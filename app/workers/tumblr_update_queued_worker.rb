class TumblrUpdateQueuedWorker < ApplicationWorker
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

    # Search for the post on Tumblr.
    posts = tumblr.posts(tumblr_username, id: entry.tumblr_id)

    if posts['status'].present? && posts['status'] == 404
      # If searching for the post returns a 404, it means the post either doesn't exist,
      # or it was published, which changed the ID, so loop through all the published posts to find it.
      # (If a queued post is published, its previous ID becomes the `genesis_post_id`.)
      total_posts = tumblr.blog_info(tumblr_username)['blog']['posts']
      limit = 20
      offset = 0
      while offset < total_posts
        response = tumblr.posts(tumblr_username, offset: offset, limit: limit, type: 'photo')
        raise response.to_s if response['errors'].present? || (response['status'].present? && response['status'] >= 400)
        # Find the published Tumblr post with the `genesis_post_id` of the queued post.
        post = response['posts'].find { |post| post['genesis_post_id'] == entry.tumblr_id }
        if post.present?
          # Found it! Save the new ID and the reblog key, and we're done.
          entry.tumblr_id = post['id_string']
          entry.tumblr_reblog_key = post['reblog_key']
          entry.save
          return
        end
        offset += limit
      end
    else
      raise posts.to_s if posts['errors'].present? || (posts['status'].present? && posts['status'] >= 400)
      # If we found the post, then it's still in the queue. Check back later.
      post = posts['posts'][0]
      publish_time = Time.at(post['scheduled_publish_time']) + 10.minutes
      TumblrUpdateQueuedWorker.perform_at(publish_time, entry.id)
    end
  end
end
