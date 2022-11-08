class TumblrSortQueueWorker < ApplicationWorker
  sidekiq_options queue: 'low'

  def perform(tumblr_id, insert_after = 0)
    return if !Rails.env.production?
    return if ENV['TUMBLR_CONSUMER_KEY'].blank? || ENV['TUMBLR_CONSUMER_SECRET'].blank? || ENV['TUMBLR_ACCESS_TOKEN'].blank? || ENV['TUMBLR_ACCESS_TOKEN_SECRET'].blank?

    tumblr_username = Blog.first.tumblr_username
    return if tumblr_username.blank?

    tumblr = Tumblr::Client.new({
      consumer_key: ENV['TUMBLR_CONSUMER_KEY'],
      consumer_secret: ENV['TUMBLR_CONSUMER_SECRET'],
      oauth_token: ENV['TUMBLR_ACCESS_TOKEN'],
      oauth_token_secret: ENV['TUMBLR_ACCESS_TOKEN_SECRET']
    })
    
    response = tumblr.reorder_queue(tumblr_username, post_id: tumblr_id, insert_after: insert_after)

    raise response.to_s if response['errors'].present? || (response['status'].present? && response['status'] >= 400)
  end
end
