class TumblrJob < ApplicationJob
  queue_as :default

  def perform(entry)
    tumblr = Tumblr::Client.new({
      consumer_key: ENV['tumblr_consumer_key'],
      consumer_secret: ENV['tumblr_consumer_secret'],
      oauth_token: ENV['tumblr_access_token'],
      oauth_token_secret: ENV['tumblr_access_token_secret']
    })

    opts = {
      tags: entry.tag_list.join(', '),
      slug: entry.slug,
      caption: entry.formatted_content,
      link: entry.permalink_url,
      data: entry.photos.map { |p| open(p.original_url).path }
    }

    tumblr.photo(ENV['tumblr_domain'], opts) if Rails.env.production?
  end
end
