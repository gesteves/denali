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

    post = tumblr.posts(ENV['TUMBLR_DOMAIN'], id: tumblr_id)
    post_type = post['posts'][0]['type']
    post_format = post['posts'][0]['format']
    use_html = post_format == 'html'

    opts = {
      id: tumblr_id,
      type: post_type,
      tags: entry.tumblr_tags,
      slug: entry.slug,
      caption: entry.tumblr_caption(html: use_html),
      link: entry.permalink_url,
      source_url: entry.permalink_url,
      format: post_format,
      date: entry.published_at.to_s
    }

    opts[:data] = entry.photos.map { |p| URI.open(p.url(w: 2048)).path } if entry.is_photo?

    response = tumblr.edit(ENV['TUMBLR_DOMAIN'], opts)

    if response['errors'].present? || (response['status'].present? && response['status'] >= 400)
      raise response.to_s
    end
  end
end
