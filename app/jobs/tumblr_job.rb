class TumblrJob < ApplicationJob
  queue_as :default

  def perform(entry)
    return if !entry.is_published? || !entry.is_photo? || !Rails.env.production?
    tumblr = Tumblr::Client.new({
      consumer_key: ENV['tumblr_consumer_key'],
      consumer_secret: ENV['tumblr_consumer_secret'],
      oauth_token: ENV['tumblr_access_token'],
      oauth_token_secret: ENV['tumblr_access_token_secret']
    })

    opts = {
      tags: entry.tumblr_hashtags,
      slug: entry.slug,
      caption: entry.formatted_content(link_title: true),
      link: entry.permalink_url,
      data: entry.photos.map { |p| open(p.url(w: 2560, fm: 'jpg')).path },
      state: 'queue'
    }

    response = tumblr.photo(ENV['tumblr_domain'], opts)
    if response['errors'].present?
      raise response['errors']
    elsif response['status'].present? && response['status'] >= 400
      raise response['msg']
    end
  end

end
