class TumblrReblogWorker < ApplicationWorker
  sidekiq_options queue: 'high'

  def perform(entry_id, text)
    return if !Rails.env.production?
    return if ENV['TUMBLR_CONSUMER_KEY'].blank? || ENV['TUMBLR_CONSUMER_SECRET'].blank? || ENV['TUMBLR_ACCESS_TOKEN'].blank? || ENV['TUMBLR_ACCESS_TOKEN_SECRET'].blank?

    entry = Entry.published.find(entry_id)
    return unless entry.posted_on_tumblr?

    tumblr_username = entry.blog.tumblr_username
    return if tumblr_username.blank?

    tumblr = Tumblr::Client.new({
      consumer_key: ENV['TUMBLR_CONSUMER_KEY'],
      consumer_secret: ENV['TUMBLR_CONSUMER_SECRET'],
      oauth_token: ENV['TUMBLR_ACCESS_TOKEN'],
      oauth_token_secret: ENV['TUMBLR_ACCESS_TOKEN_SECRET']
    })

    opts = {
      id: entry.tumblr_id,
      reblog_key: entry.tumblr_reblog_key,
      comment: text.presence,
      tags: entry.tumblr_tags,
      slug: entry.slug,
      format: 'markdown',
      state: 'queue'
    }.compact

    response = tumblr.reblog(tumblr_username, opts)
    raise response.to_s if response['errors'].present? || (response['status'].present? && response['status'] >= 400)
  end
end
