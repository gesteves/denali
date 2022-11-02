class TumblrWorker < ApplicationWorker
  sidekiq_options queue: 'high'

  def perform(entry_id, tumblr_id = nil)
    return if ENV['ENABLE_TUMBLR'].blank?
    entry = Entry.published.find(entry_id)
    raise UnprocessedPhotoError if entry.is_photo? && !entry.photos_have_dimensions?

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
      response = tumblr.posts(ENV['TUMBLR_DOMAIN'], id: tumblr_id)
      raise response.to_s if response['errors'].present? || (response['status'].present? && response['status'] >= 400)

      tumblr_post_format = response['posts'][0]['format']
      tumblr_post_type = response['posts'][0]['type']
      is_published_on_tumblr = response['posts'][0]['state'] == 'published'
      use_html = tumblr_post_format == 'html'

      opts[:id] = tumblr_id
      opts[:type] = tumblr_post_type.to_sym
      opts[:date] = entry.published_at.to_s if is_published_on_tumblr
      opts[:caption] = entry.tumblr_caption(html: use_html)
      opts[:format] = tumblr_post_format
      tumblr.edit(ENV['TUMBLR_DOMAIN'], opts)
    else
      opts[:caption] = entry.tumblr_caption
      opts[:state] = ENV['TUMBLR_QUEUE'].present? ? 'queue' : 'published'
      opts[:format] = 'markdown'
      if entry.is_photo?
        tumblr.photo(ENV['TUMBLR_DOMAIN'], opts)
      else
        tumblr.text(ENV['TUMBLR_DOMAIN'], opts)
      end
    end

    raise response.to_s if response['errors'].present? || (response['status'].present? && response['status'] >= 400)
  end
end
