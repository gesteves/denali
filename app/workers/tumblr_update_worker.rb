class TumblrUpdateWorker < ApplicationWorker
  sidekiq_options queue: 'low'

  def perform(entry_id, tumblr_id)
    return if !Rails.env.production?
    return if ENV['TUMBLR_CONSUMER_KEY'].blank? || ENV['TUMBLR_CONSUMER_SECRET'].blank? || ENV['TUMBLR_ACCESS_TOKEN'].blank? || ENV['TUMBLR_ACCESS_TOKEN_SECRET'].blank?

    entry = Entry.published.find(entry_id)
    return if !entry.is_photo?
    raise UnprocessedPhotoError if entry.is_photo? && !entry.photos_have_dimensions?

    tumblr_username = entry.blog.tumblr_username
    return if tumblr_username.blank?

    tumblr = Tumblr::Client.new({
      consumer_key: ENV['TUMBLR_CONSUMER_KEY'],
      consumer_secret: ENV['TUMBLR_CONSUMER_SECRET'],
      oauth_token: ENV['TUMBLR_ACCESS_TOKEN'],
      oauth_token_secret: ENV['TUMBLR_ACCESS_TOKEN_SECRET']
    })

    posts = tumblr.posts(tumblr_username, id: tumblr_id)
    raise posts.to_s if posts['errors'].present? || (posts['status'].present? && posts['status'] >= 400)

    post = posts['posts'][0]
    post_format = post['format']
    post_type = post['type']
    use_html = post_format == 'html'

    opts = {
      id: tumblr_id,
      type: post_type.to_sym,
      caption: entry.tumblr_caption(html: use_html),
      format: post_format,
      tags: entry.tumblr_tags,
      slug: entry.slug,
      source_url: entry.permalink_url,
      date: entry.published_at.to_s,
      data: entry&.photos&.map { |p| URI.open(p.url(w: 2048)).path }
    }
    
    response = tumblr.edit(tumblr_username, opts)

    raise response.to_s if response['errors'].present? || (response['status'].present? && response['status'] >= 400)
  end
end
