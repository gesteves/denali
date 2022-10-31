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

    response = tumblr.posts(ENV['TUMBLR_DOMAIN'], id: tumblr_id)
    raise response.to_s if response['errors'].present? || (response['status'].present? && response['status'] >= 400)

    post_format = response['posts'][0]['format']
    link_url = response['posts'][0]['link_url']
    is_published = response['posts'][0]['state'] == 'published'
    use_html = post_format == 'html'

    opts = {
      id: tumblr_id,
      tags: entry.tumblr_tags,
      slug: entry.slug,
      caption: entry.tumblr_caption(html: use_html),
      source_url: entry.permalink_url,
      format: post_format
    }

    opts[:date] = entry.published_at.to_s if is_published
    opts[:link] = '' if link_url.present?

    response = tumblr.edit(ENV['TUMBLR_DOMAIN'], opts)
    raise response.to_s if response['errors'].present? || (response['status'].present? && response['status'] >= 400)
  end
end
