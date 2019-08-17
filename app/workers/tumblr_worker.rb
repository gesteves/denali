class TumblrWorker < ApplicationWorker
  sidekiq_options queue: 'high'

  def perform(entry_id, now = false)
    entry = Entry.published.find(entry_id)
    return if !Rails.env.production?
    tumblr = Tumblr::Client.new({
      consumer_key: ENV['tumblr_consumer_key'],
      consumer_secret: ENV['tumblr_consumer_secret'],
      oauth_token: ENV['tumblr_access_token'],
      oauth_token_secret: ENV['tumblr_access_token_secret']
    })

    opts = {
      tags: entry.combined_tags.map(&:name).uniq.sort.map(&:downcase).join(', '),
      slug: entry.slug,
      caption: entry.formatted_content(link_title: true),
      link: entry.permalink_url,
      source_url: entry.permalink_url,
      state: now ? 'published' : 'queue'
    }

    response = if entry.is_photo?
      opts[:data] = entry.photos.map { |p| open(p.url(w: 1280, fm: 'jpg')).path }
      tumblr.photo(ENV['tumblr_domain'], opts)
    else
      tumblr.text(ENV['tumblr_domain'], opts)
    end

    if response['errors'].present? || (response['status'].present? && response['status'] >= 400)
      raise response.to_s
    end
  end
end
