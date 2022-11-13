class TumblrMetadataWorker < ApplicationWorker
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
    # Raise exception if we get any error status EXCEPT a 404
    raise posts.to_s if posts['errors'].present? || (posts['status'].present? && posts['status'] >= 400 && posts['status'] != 404)
    post = posts.dig('posts', 0)
    post_changed_state = post.blank?

    # If we got a 404, it means the post was not found, either because it doesn't exist anymore,
    # or because it was queued and got published, which made it change its ID.
    # If it's the latter, loop throgh all published posts to find the one with a matching `genesis_post_id`.
    if post.blank?
      total_posts = tumblr.blog_info(tumblr_username)['blog']['posts']
      limit = 20
      offset = 0
      while offset < total_posts
        response = tumblr.posts(tumblr_username, offset: offset, limit: limit, type: 'photo')
        raise response.to_s if response['errors'].present? || (response['status'].present? && response['status'] >= 400)
        # Find the published Tumblr post with the `genesis_post_id` of the queued post.
        post = response['posts'].find { |post| post['genesis_post_id'] == entry.tumblr_id }
        break if post.present?
        offset += limit
      end
    end

    # If we still couldn't find it, then it doesn't exist anymore.
    return if post.blank?

    if post['state'] == 'published'
      # If the post is published, save the ID and reblog key.
      entry.tumblr_id = post['id_string']
      entry.tumblr_reblog_key = post['reblog_key']
      entry.save!
      TumblrUpdateWorker.perform_in(1.day, entry.id) if post_changed_state
    elsif post['state'] == 'queued'
      # If the post is queued, the Tumblr ID will change when it's published,
      # so check back after it's published
      # (plus 10 minutes, because Tumblr never publishes exactly when it says it will.)
      publish_time = Time.at(post['scheduled_publish_time']) + 10.minutes
      publish_time = 1.hour.from_now if publish_time <= Time.now
      TumblrMetadataWorker.perform_at(publish_time, entry.id)
    end
  end
end
