class TumblrWorker < ApplicationWorker
  sidekiq_options queue: 'high'

  def perform(entry_id, tumblr_id = nil)
    return if !Rails.env.production?
    return if ENV['TUMBLR_CONSUMER_KEY'].blank? || ENV['TUMBLR_CONSUMER_SECRET'].blank? || ENV['TUMBLR_ACCESS_TOKEN'].blank? || ENV['TUMBLR_ACCESS_TOKEN_SECRET'].blank?

    entry = Entry.published.find(entry_id)
    return if !entry.is_photo?
    raise UnprocessedPhotoError if entry.is_photo? && !entry.photos_have_dimensions?

    blog = entry.blog
    return if blog.tumblr.blank?

    tumblr_username = blog.tumblr_username

    tumblr = Tumblr::Client.new({
      consumer_key: ENV['TUMBLR_CONSUMER_KEY'],
      consumer_secret: ENV['TUMBLR_CONSUMER_SECRET'],
      oauth_token: ENV['TUMBLR_ACCESS_TOKEN'],
      oauth_token_secret: ENV['TUMBLR_ACCESS_TOKEN_SECRET']
    })

    opts = {
      tags: entry.tumblr_tags,
      slug: entry.slug,
      source_url: entry.permalink_url,
      data: entry&.photos&.map { |p| URI.open(p.url(w: 2048)).path }
    }.compact

    response = if tumblr_id.present?
      posts = tumblr.posts(tumblr_username, id: tumblr_id)
      raise posts.to_s if posts['errors'].present? || (posts['status'].present? && posts['status'] >= 400)

      post = posts['posts'][0]
      post_format = post['format']
      post_type = post['type']
      is_published_on_tumblr = post['state'] == 'published'
      use_html = post_format == 'html'

      opts[:id] = tumblr_id
      opts[:type] = post_type.to_sym
      opts[:date] = entry.published_at.to_s if is_published_on_tumblr
      opts[:caption] = entry.tumblr_caption(html: use_html)
      opts[:format] = post_format
      tumblr.edit(tumblr_username, opts)
    else
      blog_info = tumblr.blog_info(tumblr_username)
      raise blog_info.to_s if blog_info['errors'].present? || (blog_info['status'].present? && blog_info['status'] >= 400)
      
      opts[:caption] = entry.tumblr_caption
      opts[:state] = blog_info['blog']['queue'] > 0 ? 'queue' : 'published'
      opts[:format] = 'markdown'
      tumblr.photo(tumblr_username, opts)
    end

    raise response.to_s if response['errors'].present? || (response['status'].present? && response['status'] >= 400)
  end
end
