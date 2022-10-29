class TumblrWorker < ApplicationWorker
  sidekiq_options queue: 'high'

  def perform(entry_id, now = false)
    return if ENV['ENABLE_TUMBLR'].blank?
    entry = Entry.published.find(entry_id)
    raise UnprocessedPhotoError if entry.is_photo? && !entry.photos_processed?

    tumblr = Tumblr::Client.new({
      consumer_key: ENV['TUMBLR_CONSUMER_KEY'],
      consumer_secret: ENV['TUMBLR_CONSUMER_SECRET'],
      oauth_token: ENV['TUMBLR_ACCESS_TOKEN'],
      oauth_token_secret: ENV['TUMBLR_ACCESS_TOKEN_SECRET']
    })

    opts = {
      tags: entry.tumblr_tags,
      slug: entry.slug,
      caption: entry.tumblr_caption,
      link: entry.permalink_url,
      source_url: entry.permalink_url,
      state: now ? 'published' : 'queue',
      format: 'markdown'
    }

    response = if entry.is_photo?
      opts[:data] = entry.photos.map { |p| URI.open(p.url(w: 1280)).path }
      tumblr.photo(ENV['TUMBLR_DOMAIN'], opts)
    else
      tumblr.text(ENV['TUMBLR_DOMAIN'], opts)
    end

    if response['errors'].present? || (response['status'].present? && response['status'] >= 400)
      raise response.to_s
    end
  end
end
