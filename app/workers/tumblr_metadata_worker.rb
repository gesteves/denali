class TumblrMetadataWorker < ApplicationWorker
  sidekiq_options queue: 'low'

  # This worker does a couple things to fetch and store
  # metadata about the Tumblr post associated with an entry,
  # namely its `tumblr_id` and `tumblr_reblog_key` so the
  # Tumblr post can be updated, reblogged, etc.
  # To do that, it looks up the Tumblr post by ID.
  # - If it finds it, and the post is published,
  #   then it saves the `tumblr_id` and `tumblr_reblog_key`.
  # - If it finds it, and the post is queued,
  #   then it looks up its `scheduled_publish_time` and enqueues
  #   itself again for that time, so we can try again after its published.
  # - If it doesn't find it, it's because it either was deleted or it changed
  #   IDs after changing state from queued to published, so it tries to find it
  #   in the list of published posts. If found, it saves the `tumblr_id` and `tumblr_reblog_key`.
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
    # Raise exception if we get any error status EXCEPT a 404!
    raise posts.to_s if posts['errors'].present? || (posts['status'].present? && posts['status'] >= 400 && posts['status'] != 404)
    post = posts.dig('posts', 0)
    post_changed_state = false

    # If we got a 404, it means the post was not found either because it doesn't exist anymore,
    # or because it changed state from queued to published, which made it change its ID.
    # If it's the latter, loop through all published posts to find the one with a matching `genesis_post_id`,
    # which is the ID it had when it was queued.
    if post.blank?
      total_posts = tumblr.blog_info(tumblr_username)['blog']['posts']
      limit = 20
      offset = 0
      while offset < total_posts
        response = tumblr.posts(tumblr_username, offset: offset, limit: limit, type: 'photo')
        raise response.to_s if response['errors'].present? || (response['status'].present? && response['status'] >= 400)
        # Find the published Tumblr post with the `genesis_post_id` of the queued post.
        post = response['posts'].find { |post| post['genesis_post_id'] == entry.tumblr_id }
        if post.present?
          post_changed_state = true
          break
        end
        offset += limit
      end
    end

    # If we still couldn't find it, then it doesn't exist anymore,
    # so there's nothing else to do.
    return if post.blank?

    if post['state'] == 'published'
      # If the post is published, save the Tumblr ID and reblog key...
      entry.tumblr_id = post['id_string']
      entry.tumblr_reblog_key = post['reblog_key']
      entry.save!
      # If it changed state (as opposed as being published directly,)
      # enqueue an update so the Tumblr timestamp matches its corresponding entry.
      # (a day from now because otherwise it'll disappear from the dashboard.)
      TumblrUpdateWorker.perform_in(1.day, entry.id) if post_changed_state
    elsif post['state'] == 'queued'
      # If the post is queued, the Tumblr ID will change when it's published,
      # so enqueue a retry shortly after its scheduled publish time.
      publish_time = Time.at(post['scheduled_publish_time'])
      # If publish time is in the past, then the post is late
      # (Tumblr doesn't really publish exactly at the scheduled time);
      # raise an exception so we can retry.
      raise TumblrPostDelayedPublishError if publish_time <= Time.now
      TumblrMetadataWorker.perform_at(publish_time, entry.id)
    end
  end
end
