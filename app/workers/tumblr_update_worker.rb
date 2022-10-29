class TumblrUpdateWorker < ApplicationWorker
  sidekiq_options queue: 'low'

  def perform(entry_id, tumblr_id)
    return if ENV['ENABLE_TUMBLR'].blank?
    entry = Entry.published.find(entry_id)

    tumblr = Tumblr::Client.new({
      consumer_key: ENV['TUMBLR_CONSUMER_KEY'],
      consumer_secret: ENV['TUMBLR_CONSUMER_SECRET'],
      oauth_token: ENV['TUMBLR_ACCESS_TOKEN'],
      oauth_token_secret: ENV['TUMBLR_ACCESS_TOKEN_SECRET']
    })

    opts = {
      id: tumblr_id,
      tags: entry.tumblr_tags,
      slug: entry.slug,
      caption: entry.tumblr_caption,
      link: entry.permalink_url,
      source_url: entry.permalink_url,
      format: 'markdown'
    }

    response = tumblr.edit(ENV['TUMBLR_DOMAIN'], opts)

    if response['errors'].present? || (response['status'].present? && response['status'] >= 400)
      raise response.to_s
    end
  end
end
