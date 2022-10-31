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

    tumblr_post_format = response['posts'][0]['format']
    tumblr_post_type = response['posts'][0]['type']
    is_published_on_tumblr = response['posts'][0]['state'] == 'published'
    use_html = tumblr_post_format == 'html'

    opts = {
      id: tumblr_id,
      type: tumblr_post_type.to_sym,
      tags: entry.tumblr_tags,
      slug: entry.slug,
      caption: entry.tumblr_caption(html: use_html),
      source_url: entry.permalink_url,
      format: tumblr_post_format
    }

    opts[:date] = entry.published_at.to_s if is_published_on_tumblr
    opts[:data] = entry.photos.map { |p| URI.open(p.url(w: 2048)).path } if entry.is_photo?

    response = tumblr.edit(ENV['TUMBLR_DOMAIN'], opts)
    raise response.to_s if response['errors'].present? || (response['status'].present? && response['status'] >= 400)
  end
end
