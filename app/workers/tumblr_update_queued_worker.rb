class TumblrUpdateQueuedWorker < ApplicationWorker
  sidekiq_options queue: 'low'

  sidekiq_retry_in do |count, exception|
    case exception
    when TumblrPostNotPublishedError
      60
    end
  end

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
    raise TumblrPostNotPublishedError unless posts['status'].present? && posts['status'] == 404
    # If searching for the post DOESN'T return a 404, it means the post is still in the queue,
    # so raise an exception to trigger a retry.

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
        TumblrUpdateWorker.perform_in(1.day, entry.id)
        return
      end
      offset += limit
    end
  end
end
